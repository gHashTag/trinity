#!/usr/bin/env python3
"""Train MNIST MLP 784→128→10 and export to BENCH-004 binary format."""

import os
import struct
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from torchvision import datasets, transforms

# 1. Hyperparameters
input_dim = 784
hidden_dim = 128
output_dim = 10
batch_size = 128
epochs = 8
lr = 1e-3
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# 2. Dataset & loaders
transform = transforms.Compose([
    transforms.ToTensor(),              # [0,1]
    transforms.Lambda(lambda x: x.view(-1))  # flatten to 784
])

train_ds = datasets.MNIST(
    root="./data",
    train=True,
    download=False,  # Already downloaded
    transform=transform,
)
test_ds = datasets.MNIST(
    root="./data",
    train=False,
    download=False,  # Already downloaded
    transform=transform,
)

train_loader = DataLoader(train_ds, batch_size=batch_size, shuffle=True)
test_loader = DataLoader(test_ds, batch_size=1000, shuffle=False)

# 3. Model
class MLP(nn.Module):
    def __init__(self, in_dim, hid_dim, out_dim):
        super().__init__()
        self.fc1 = nn.Linear(in_dim, hid_dim)
        self.fc2 = nn.Linear(hid_dim, out_dim)

    def forward(self, x):
        x = self.fc1(x)
        x = torch.relu(x)
        x = self.fc2(x)
        return x

model = MLP(input_dim, hidden_dim, output_dim).to(device)
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=lr)

# 4. Train loop
def train_epoch(epoch):
    model.train()
    total_loss = 0.0
    for x, y in train_loader:
        x = x.to(device)
        y = y.to(device)

        optimizer.zero_grad()
        logits = model(x)
        loss = criterion(logits, y)
        loss.backward()
        optimizer.step()

        total_loss += loss.item() * x.size(0)

    avg_loss = total_loss / len(train_loader.dataset)
    print(f"Epoch {epoch}: train loss {avg_loss:.4f}")

def eval_model():
    model.eval()
    correct = 0
    total = 0
    loss_sum = 0.0
    with torch.no_grad():
        for x, y in test_loader:
            x = x.to(device)
            y = y.to(device)
            logits = model(x)
            loss = criterion(logits, y)
            loss_sum += loss.item() * x.size(0)

            preds = logits.argmax(dim=1)
            correct += (preds == y).sum().item()
            total += y.size(0)
    acc = 100.0 * correct / total
    avg_loss = loss_sum / total
    print(f"Test: acc {acc:.2f}%, loss {avg_loss:.4f}")
    return acc, avg_loss

for epoch in range(1, epochs + 1):
    train_epoch(epoch)
    acc, _ = eval_model()
    # ранний стоп, если уже попали в нужный диапазон
    if acc >= 98.0:
        break

# 5. Export to binary format
os.makedirs("results", exist_ok=True)
out_path = "results/mnist_mlp_784x128x10.bin"

state = model.state_dict()
W1 = state["fc1.weight"].cpu().contiguous()  # [128, 784]
b1 = state["fc1.bias"].cpu().contiguous()    # [128]
W2 = state["fc2.weight"].cpu().contiguous()  # [10, 128]
b2 = state["fc2.bias"].cpu().contiguous()    # [10]

with open(out_path, "wb") as f:
    # header (little-endian)
    f.write(struct.pack("<I", 0x4D4E4953))  # magic "MNIS"
    f.write(struct.pack("<I", 1))           # version
    f.write(struct.pack("<I", input_dim))
    f.write(struct.pack("<I", hidden_dim))
    f.write(struct.pack("<I", output_dim))

    # tensors in row-major, float32, little-endian
    f.write(W1.numpy().astype("float32").tobytes(order="C"))
    f.write(b1.numpy().astype("float32").tobytes(order="C"))
    f.write(W2.numpy().astype("float32").tobytes(order="C"))
    f.write(b2.numpy().astype("float32").tobytes(order="C"))

print(f"Saved weights to {out_path}")
