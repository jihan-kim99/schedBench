import torch
import torch.nn as nn
import torch.distributed.rpc as rpc
import torch.distributed.autograd as dist_autograd
from torch.distributed.optim import DistributedOptimizer
import torch.optim as optim
import os

from torchtext.datasets import PennTreebank
from torchtext.data.utils import get_tokenizer
from collections import Counter
from torchtext.vocab import Vocab

# Tokenizer and data loading
tokenizer = get_tokenizer("basic_english")
train_iter = PennTreebank(split='train')

# Build the vocabulary
counter = Counter()
for line in train_iter:
    counter.update(tokenizer(line))
vocab = Vocab(counter, max_size=5000)

# Prepare the data
vocab_size = len(vocab)
seq_len = 50
batch_size = 32
embed_size = 128
hidden_size = 256
output_size = 5000

def batchify(data, bsz):
    # Convert tokenized data into a tensor, then batch it
    tokens = [vocab[token] for token in tokenizer(data)]
    num_batches = len(tokens) // (bsz * seq_len)
    tokens = tokens[:num_batches * bsz * seq_len]
    return torch.tensor(tokens).view(bsz, -1)

# Example usage
train_data = batchify(train_iter, batch_size)

# Embedding Table Component
class EmbeddingModel(nn.Module):
    def __init__(self, vocab_size, embed_size):
        super(EmbeddingModel, self).__init__()
        self.embedding = nn.Embedding(vocab_size, embed_size)

    def forward(self, x):
        return self.embedding(x)

# LSTM Component
class LSTMModel(nn.Module):
    def __init__(self, embed_size, hidden_size):
        super(LSTMModel, self).__init__()
        self.lstm = nn.LSTM(embed_size, hidden_size, batch_first=True)

    def forward(self, x, h):
        return self.lstm(x, h)

# Decoder Component
class DecoderModel(nn.Module):
    def __init__(self, hidden_size, output_size):
        super(DecoderModel, self).__init__()
        self.fc = nn.Linear(hidden_size, output_size)

    def forward(self, x):
        return self.fc(x)


# Distributed forward and backward pass using RPC

# Create remote references to the model components
embedding_rref = rpc.remote("worker1", EmbeddingModel, args=(vocab_size, embed_size))
lstm_rref = rpc.remote("worker2", LSTMModel, args=(embed_size, hidden_size))
decoder_rref = rpc.remote("worker3", DecoderModel, args=(hidden_size, output_size))

def forward(input_data, hidden):
    # Forward pass through embedding -> lstm -> decoder
    embed_output = embedding_rref.rpc_sync().forward(input_data)
    lstm_output, hidden = lstm_rref.rpc_sync().forward(embed_output, hidden)
    output = decoder_rref.rpc_sync().forward(lstm_output)
    return output, hidden

def train_step(input_data, target, hidden, loss_fn):
    # Forward pass with distributed autograd context
    with dist_autograd.context() as context_id:
        output, hidden = forward(input_data, hidden)
        loss = loss_fn(output, target)
        
        # Backward pass
        dist_autograd.backward(context_id, [loss])
        
        # Update parameters with distributed optimizer
        optimizer = DistributedOptimizer(
            optim.SGD,
            # Get all remote parameters from the RRefs
            params=[
                embedding_rref.remote().parameters(),
                lstm_rref.remote().parameters(),
                decoder_rref.remote().parameters()
            ]
        )
        optimizer.step(context_id)
    
    return loss.item()

def run_worker(rank, world_size):
    rpc.init_rpc(f"worker{rank}", rank=rank, world_size=world_size)
    
    if rank == 0:
        input_data = torch.randint(0, vocab_size, (batch_size, seq_len))
        target = torch.randint(0, output_size, (batch_size,))
        hidden = None  

        # Define a loss function
        loss_fn = nn.CrossEntropyLoss()

        # Train the model in a single step
        loss = train_step(input_data, target, hidden, loss_fn)
        print(f"Loss: {loss}")

    rpc.shutdown()

if __name__ == "__main__":
    rank = int(os.environ['RANK'])
    world_size = int(os.environ['WORLD_SIZE'])
    
    run_worker(rank, world_size)
