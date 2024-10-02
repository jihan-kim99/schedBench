import os
import threading
import requests
import socket
import time
import logging

import torch
import torch.nn as nn
import torch.distributed.autograd as dist_autograd
import torch.distributed.rpc as rpc
import torch.optim as optim
from torch.distributed.optim import DistributedOptimizer

from torch.distributed.rpc import RRef

from torchvision.models.resnet import Bottleneck


#########################################################
#           Define Model Parallel ResNet50              #
#########################################################

# In order to split the ResNet50 and place it on two different workers, we
# implement it in two model shards. The ResNetBase class defines common
# attributes and methods shared by two shards. ResNetShard1 and ResNetShard2
# contain two partitions of the model layers respectively.

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

num_classes = 1000

tik = 0
network_time = 0


def conv1x1(in_planes, out_planes, stride=1):
    """1x1 convolution"""
    return nn.Conv2d(in_planes, out_planes, kernel_size=1, stride=stride, bias=False)

class ResNetBase(nn.Module):
    def __init__(self, block, inplanes, num_classes=1000,
                 groups=1, width_per_group=64, norm_layer=None):
        super(ResNetBase, self).__init__()

        self._lock = threading.Lock()
        self._block = block
        self._norm_layer = nn.BatchNorm2d
        self.inplanes = inplanes
        self.dilation = 1
        self.groups = groups
        self.base_width = width_per_group

    def _make_layer(self, planes, blocks, stride=1):
        norm_layer = self._norm_layer
        downsample = None
        previous_dilation = self.dilation
        if stride != 1 or self.inplanes != planes * self._block.expansion:
            downsample = nn.Sequential(
                conv1x1(self.inplanes, planes * self._block.expansion, stride),
                norm_layer(planes * self._block.expansion),
            )

        layers = []
        layers.append(self._block(self.inplanes, planes, stride, downsample, self.groups,
                                  self.base_width, previous_dilation, norm_layer))
        self.inplanes = planes * self._block.expansion
        for _ in range(1, blocks):
            layers.append(self._block(self.inplanes, planes, groups=self.groups,
                                      base_width=self.base_width, dilation=self.dilation,
                                      norm_layer=norm_layer))

        return nn.Sequential(*layers)

    def parameter_rrefs(self):
        r"""
        Create one RRef for each parameter in the given local module, and return a
        list of RRefs.
        """
        return [RRef(p) for p in self.parameters()]


class ResNetShard1(ResNetBase):
    """
    The first part of ResNet.
    """
    def __init__(self, device, *args, **kwargs):
        super(ResNetShard1, self).__init__(
            Bottleneck, 64, num_classes=num_classes, *args, **kwargs)

        self.device = device
        self.seq = nn.Sequential(
            nn.Conv2d(3, self.inplanes, kernel_size=7, stride=2, padding=3, bias=False),
            self._norm_layer(self.inplanes),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(kernel_size=3, stride=2, padding=1),
            self._make_layer(64, 3),
            self._make_layer(128, 4, stride=2)
        ).to(self.device)

        for m in self.modules():
            if isinstance(m, nn.Conv2d):
                nn.init.kaiming_normal_(m.weight, mode='fan_out', nonlinearity='relu')
            elif isinstance(m, nn.BatchNorm2d):
                nn.init.ones_(m.weight)
                nn.init.zeros_(m.bias)

    def forward(self, x_rref):
        x = x_rref.to_here().to(self.device)
        with self._lock:
            out =  self.seq(x)
        return out.cpu()


class ResNetShard2(ResNetBase):
    """
    The second part of ResNet.
    """
    def __init__(self, device, *args, **kwargs):
        super(ResNetShard2, self).__init__(
            Bottleneck, 512, num_classes=num_classes, *args, **kwargs)

        self.device = device
        self.seq = nn.Sequential(
            self._make_layer(256, 6, stride=2),
            self._make_layer(512, 3, stride=2),
            nn.AdaptiveAvgPool2d((1, 1)),
        ).to(self.device)

        self.fc =  nn.Linear(512 * self._block.expansion, num_classes).to(self.device)

    def forward(self, x_rref):
        x = x_rref.to_here().to(self.device)
        with self._lock:
            out = self.fc(torch.flatten(self.seq(x), 1))
        return out.cpu()


class DistResNet50(nn.Module):
    """
    Assemble two parts as an nn.Module and define pipelining logic
    """
    def __init__(self, split_size, workers, *args, **kwargs):
        super(DistResNet50, self).__init__()

        self.split_size = split_size

        # Put the first part of the ResNet50 on workers[0]
        self.p1_rref = rpc.remote(
            workers[0],
            ResNetShard1,
            args = ("cpu",) + args,
            kwargs = kwargs
        )

        # Put the second part of the ResNet50 on workers[1]
        self.p2_rref = rpc.remote(
            workers[1],
            ResNetShard2,
            args = ("cpu",) + args,
            kwargs = kwargs
        )

    def forward(self, xs):
        # Split the input batch xs into micro-batches, and collect async RPC
        # futures into a list
        out_futures = []
        for x in iter(xs.split(self.split_size, dim=0)):
            x_rref = RRef(x)
            y_rref = self.p1_rref.remote().forward(x_rref)
            z_fut = self.p2_rref.rpc_async().forward(y_rref)
            out_futures.append(z_fut)

        # collect and cat all output tensors into one tensor.
        return torch.cat(torch.futures.wait_all(out_futures))

    def parameter_rrefs(self):
        remote_params = []
        remote_params.extend(self.p1_rref.remote().parameter_rrefs().to_here())
        remote_params.extend(self.p2_rref.remote().parameter_rrefs().to_here())
        return remote_params


#########################################################
#                   Run RPC Processes                   #
#########################################################
class Timer:
    def __init__(self):
        self.start_time = None
        self.total_time = 0

    def start(self):
        self.start_time = time.time()

    def stop(self):
        if self.start_time is not None:
            self.total_time += time.time() - self.start_time
            self.start_time = None

    def reset(self):
        self.total_time = 0
        self.start_time = None

network_timer = Timer()
execution_timer = Timer()


num_batches = 2
batch_size = 120
image_w = 128
image_h = 128

def run_master(split_size):
    execution_timer.start()
    logger.info("master is running")
    
    model = DistResNet50(split_size, ["worker1", "worker2"])

    loss_fn = nn.MSELoss()
    opt = DistributedOptimizer(
        optim.SGD,
        model.parameter_rrefs(),
        lr=0.05,
    )

    one_hot_indices = torch.LongTensor(batch_size) \
                           .random_(0, num_classes) \
                           .view(batch_size, 1)

    for i in range(num_batches):
        logger.info(f"Processing batch {i} out of {num_batches}")
        # generate random inputs and labels
        inputs = torch.randn(batch_size, 3, image_w, image_h)
        labels = torch.zeros(batch_size, num_classes) \
                      .scatter_(1, one_hot_indices, 1)

        # The distributed autograd context is the dedicated scope for the
        # distributed backward pass to store gradients, which can later be
        # retrieved using the context_id by the distributed optimizer.
        with dist_autograd.context() as context_id:
            network_timer.start()
            outputs = model(inputs)
            network_timer.stop()

            loss = loss_fn(outputs, labels)

            dist_autograd.backward(context_id, [loss])
            opt.step(context_id)


def run_worker(rank, world_size, num_split):
    execution_timer.start()
    logger.info(f"worker {rank} is running")
    # Higher timeout is added to accommodate for kernel compilation time in case of ROCm.
    options = rpc.TensorPipeRpcBackendOptions(num_worker_threads=256, rpc_timeout=300)

    if rank == 0:
        rpc.init_rpc(
            "master",
            rank=rank,
            world_size=world_size,
            rpc_backend_options=options
        )
        run_master(num_split)
    else:
        rpc.init_rpc(
            f"worker{rank}",
            rank=rank,
            world_size=world_size,
            rpc_backend_options=options
        )
        pass
        # block until all rpcs finish
    rpc.shutdown()
    execution_timer.stop()

    if rank == 0:
        logger.info(f"Total execution time: {execution_timer.total_time:.2f} seconds")
        logger.info(f"Total network communication time: {network_timer.total_time:.2f} seconds")
        logger.info(f"Percentage of time spent on network communication: {(network_timer.total_time/execution_timer.total_time)*100:.2f}%")


if __name__=="__main__":

    url = "http://ip-service:8000/"

    world_size = int(os.environ['WORLD_SIZE'])
    rank = int(os.environ['RANK'])
    logger.info(f'World Size: {world_size}, Rank: {rank}')

    res = ''
    
    while res == '':
        try:
            # Sending request with rank and IP address
            response = requests.post(url, json={
                'rank': rank, 
                'ip': socket.gethostbyname(socket.gethostname())
            })
            # Parse response
            response_json = response.json()
            logger.info(response_json)
            if rank == 0:
                # If rank is 0, logger.info own IP address from the response
                logger.info(f'IP Address: {response_json["message"]}')
                res = 'localhost'
                break
            else:
                # Otherwise, retrieve and set the IP address from the response
                res = response_json['ip']
                logger.info(f'IP Address: {res}')
        except requests.exceptions.RequestException as e:
            # Catch specific exceptions related to the request
            logger.info(f"Request failed: {e}")
        except Exception as e:
            # Catch other exceptions
            logger.info(f"An error occurred: {e}")
        time.sleep(5)
    
    if(rank == 0):
        os.environ['MASTER_ADDR'] = 'localhost'
        os.environ['MASTER_PORT'] = '80'
    else:
        os.environ['MASTER_ADDR'] = res
        logger.info(f'IP Address: {res}')
        os.environ['MASTER_PORT'] = '80'

    logger.info('start')
    
    run_worker(rank, world_size, num_split=1)