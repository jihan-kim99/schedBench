import os
import torch
import torch.nn as nn
import torch.optim as optim
import torch.distributed as dist
import torch.multiprocessing as mp
import torch.utils.data
import torch.utils.data.distributed
import torchvision.transforms as transforms
from torchvision import datasets, models

# Define the neural network model
class Net(nn.Module):
    def __init__(self):
        super(Net, self).__init__()
        self.conv1 = nn.Conv2d(1, 32, kernel_size=5)
        self.conv2 = nn.Conv2d(32, 64, kernel_size=5)
        self.fc1 = nn.Linear(1024, 128)
        self.fc2 = nn.Linear(128, 10)
    
    def forward(self, x):
        x = torch.relu(self.conv1(x))
        x = torch.max_pool2d(x, 2)
        x = torch.relu(self.conv2(x))
        x = torch.max_pool2d(x, 2)
        x = x.view(-1, 1024)
        x = torch.relu(self.fc1(x))
        x = self.fc2(x)
        return torch.log_softmax(x, dim=1)

# Parameter server setup
def parameter_server(model):
    for param in model.parameters():
        dist.broadcast(param.data, src=0)

# Training function
def train(rank, world_size):
    # Initialize the process group
    dist.init_process_group("gloo", rank=rank, world_size=world_size)
    
    # Set device
    torch.manual_seed(0)
    device = torch.device(f"cuda:{rank}" if torch.cuda.is_available() else "cpu")
    
    # Load data
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
    ])
    dataset = datasets.MNIST('/mnt/data', train=True, download=True, transform=transform)
    train_sampler = torch.utils.data.distributed.DistributedSampler(dataset, num_replicas=world_size, rank=rank)
    train_loader = torch.utils.data.DataLoader(dataset, batch_size=64, sampler=train_sampler)
    
    # Create model
    model = Net().to(device)
    model = nn.parallel.DistributedDataParallel(model, device_ids=[rank])
    
    # Define loss function and optimizer
    criterion = nn.NLLLoss().to(device)
    optimizer = optim.SGD(model.parameters(), lr=0.01, momentum=0.9)
    
    # Training loop
    model.train()
    for epoch in range(5):
        train_sampler.set_epoch(epoch)
        for batch_idx, (data, target) in enumerate(train_loader):
            data, target = data.to(device), target.to(device)
            optimizer.zero_grad()
            output = model(data)
            loss = criterion(output, target)
            loss.backward()
            optimizer.step()
            if batch_idx % 10 == 0 and rank == 0:
                print(f'Train Epoch: {epoch} [{batch_idx * len(data)}/{len(train_loader.dataset)}] Loss: {loss.item():.6f}')
    
    # Synchronize model parameters
    parameter_server(model)

    if rank == 0:
        torch.save(model.state_dict(), '/mnt/data/model/model.pth')

    # Cleanup
    dist.destroy_process_group()


if __name__ == "__main__":
    world_size = int(os.environ['WORLD_SIZE'])
    rank = int(os.environ['RANK'])
    train(rank, world_size)