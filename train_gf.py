"""
Train a linear model over GF(N) on LinguaLean features.

Usage:
    python3 train_gf.py --features path/to/features.csv \
                        --labels path/to/labels.csv \
                        --output weights.npy \
                        --N 257 \
                        --split 0.8
"""
import argparse
from typing import List

def read_csv(path: str) -> List[List[int]]:
    """Read integer matrix from CSV, skipping header."""
    with open(path) as f:
        lines = [l.strip() for l in f if l.strip()]
    if not lines:
        return []
    return [[int(v) for v in row.split(',')] for row in lines[1:]]

def mat_mul(A: List[List[int]], B: List[List[int]], N: int) -> List[List[int]]:
    """Matrix multiplication over GF(N)."""
    rowsA, colsA = len(A), len(A[0])
    colsB = len(B[0])
    result = [[0]*colsB for _ in range(rowsA)]
    for i in range(rowsA):
        for k in range(colsA):
            aik = A[i][k]
            if aik == 0:
                continue
            for j in range(colsB):
                result[i][j] = (result[i][j] + aik * B[k][j]) % N
    return result

def mat_transpose(A: List[List[int]]) -> List[List[int]]:
    rows, cols = len(A), len(A[0]) if A else 0
    return [[A[j][i] for j in range(rows)] for i in range(cols)]

def mat_inv_gf(A: List[List[int]], N: int) -> List[List[int]]:
    n = len(A)
    aug = [row[:] + [int(i==j) for j in range(n)] for i, row in enumerate(A)]
    for col in range(n):
        pivot = -1
        for row in range(col, n):
            if aug[row][col] != 0:
                pivot = row
                break
        if pivot == -1:
            raise ValueError(f"Singular matrix in GF({N})")
        aug[col], aug[pivot] = aug[pivot], aug[col]
        inv = pow(aug[col][col], -1, N)
        for j in range(2*n):
            aug[col][j] = (aug[col][j] * inv) % N
        for row in range(n):
            if row != col:
                factor = aug[row][col]
                if factor:
                    for j in range(2*n):
                        aug[row][j] = (aug[row][j] - factor * aug[col][j]) % N
    return [row[n:] for row in aug]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--features', required=True)
    parser.add_argument('--labels', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--N', type=int, default=257)
    parser.add_argument('--split', type=float, default=0.8)
    args = parser.parse_args()

    X = read_csv(args.features)
    Y = read_csv(args.labels)
    print(f"Loaded {len(X)} samples, {len(Y[0]) if Y else 0} classes")

    split = int(len(X) * args.split)
    X_train, X_test = X[:split], X[split:]
    Y_train, Y_test = Y[:split], Y[split:]

    XT = mat_transpose(X_train)
    XTX = mat_mul(XT, X_train, args.N)
    XTY = mat_mul(XT, Y_train, args.N)

    print("Inverting X^T X...")
    try:
        inv = mat_inv_gf(XTX, args.N)
    except ValueError:
        # Add ridge
        n = len(XTX)
        I = [[0]*n for _ in range(n)]
        for i in range(n):
            I[i][i] = 1
        XTX = [[(XTX[i][j] + I[i][j]) % args.N for j in range(n)] for i in range(n)]
        inv = mat_inv_gf(XTX, args.N)

    W = mat_mul(inv, XTY, args.N)
    print(f"Weight matrix: {len(W)} x {len(W[0])}")

    with open(args.output, 'w') as f:
        for row in W:
            f.write(','.join(str(v) for v in row) + '\n')
    print(f"Saved weights to {args.output}")

    if X_test:
        Y_hat = mat_mul(X_test, W, args.N)
        if len(Y_hat[0]) > 1:
            correct = sum(1 for i in range(len(Y_hat)) 
                         if max(range(len(Y_hat[i])), key=lambda j: Y_hat[i][j])
                            == max(range(len(Y_test[i])), key=lambda j: Y_test[i][j]))
            acc = correct / len(Y_hat)
            print(f"Test accuracy: {acc*100:.2f}%")
        else:
            mse = sum(sum((a-b)%args.N for a,b in zip(row1,row2)) for row1,row2 in zip(Y_hat,Y_test))
            mse = mse / (len(Y_hat)*len(Y_hat[0])) if Y_hat else 0
            print(f"Test MSE: {mse}")

if __name__ == '__main__':
    main()
