import os
import time
import torch
import torch.nn as nn
import torch.optim as optim
import torch.distributed as dist
import torch.utils.data
import torch.utils.data.distributed
import torchvision.transforms as transforms
from torchvision import datasets

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
    world_size = dist.get_world_size()  # Get the total number of nodes
    with open('/mnt/data/log', 'a') as file:
        file.write('synched\n')
        
    for param in model.parameters():
        # Create a list to hold the parameters gathered from all nodes
        gathered_params = [torch.zeros_like(param.data) for _ in range(world_size)]
        # Gather parameters from all nodes
        dist.all_gather(gathered_params, param.data)
        # Compute the average of the gathered parameters
        averaged_param = torch.mean(torch.stack(gathered_params), dim=0)
        # Update the model parameter with the averaged value
        param.data = averaged_param
        # Broadcast the averaged parameters to all nodes
        dist.broadcast(param.data, src=0)

# Training function
def train(rank, world_size):
    # Initialize the process group
    dist.init_process_group("gloo", rank=rank, world_size=world_size)
    
    # Set device
    torch.manual_seed(0)

    device = torch.device("cpu")
    
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
    model = nn.parallel.DistributedDataParallel(model)
    
    # Define loss function and optimizer
    criterion = nn.NLLLoss().to(device)
    optimizer = optim.SGD(model.parameters(), lr=0.01, momentum=0.9)
    
    # Training loop
    model.train()

    print(f'Rank: {rank}')
    print('Training started')

    for epoch in range(4):
        train_sampler.set_epoch(epoch)
        for batch_idx, (data, target) in enumerate(train_loader):
            data, target = data.to(device), target.to(device)
            optimizer.zero_grad()
            output = model(data)
            loss = criterion(output, target)
            loss.backward()
            optimizer.step()
            if batch_idx % 10 == 0 and rank == 0:
                with open('/mnt/data/log', 'a') as file:
                    file.write(f'Train Epoch: {epoch} [{batch_idx * len(data)}/{len(train_loader.dataset) / world_size}] Loss: {loss.item():.6f}\n')
                print(f'Train Epoch: {epoch} [{batch_idx * len(data)}/{len(train_loader.dataset) / world_size}] Loss: {loss.item():.6f}')
            # Synchronize model parameters
            parameter_server(model)

    if rank == 0:
        torch.save(model.state_dict(), '/mnt/data/model.pth')
        # Evaluate model accuracy
        print('eval start')
        model.eval()
        test_dataset = datasets.MNIST('/mnt/data', train=False, download=True, transform=transform)
        test_loader = torch.utils.data.DataLoader(test_dataset, batch_size=64)
        correct = 0
        total = 0
        with torch.no_grad():
            for data, target in test_loader:
                data, target = data.to(device), target.to(device)
                output = model(data)
                _, predicted = torch.max(output.data, 1)
                total += target.size(0)
                correct += (predicted == target).sum().item()
        accuracy = 100 * correct / total
        print(f'Accuracy: {accuracy}%')
        with open('/mnt/data/log', 'a') as file:
            file.write(f'Accuracy: {accuracy}%\n')

    # Cleanup
    dist.destroy_process_group()


if __name__ == "__main__":
    world_size = int(os.environ['WORLD_SIZE'])
    rank = int(os.environ['RANK'])

    while not os.path.exists('/mnt/data/ip'):
        time.sleep(1)

    with open('/mnt/data/log', 'a') as file:
        file.write('=======================\n')
        file.write(f'Rank: {rank}\n')
        file.write('Training started\n')

    with open('/mnt/data/ip', 'r') as file:
        ip_address = file.read().strip()
        os.environ['MASTER_ADDR'] = ip_address
        print(f'IP Address: {ip_address}')
    
    train(rank, world_size)

    print('Training completed')

    if(rank == 0):
        os.remove('/mnt/data/ip')