from dataclasses import dataclass

import jax
import torch.nn.functional as F
from beartype import beartype
from einops import rearrange
from jaxtyping import Float, Float32, Integer, jaxtyped
from torch import Tensor, nn


def full(size: int, fill: float) -> Float[jax.Array, " {size}"]:
    return jax.numpy.full((size,), fill)


class SomeClass:
    some_value = 5

    def full(self, fill: float) -> Float[jax.Array, " {self.some_value}+3"]:
        return jax.numpy.full((self.some_value + 3,), fill)


# note: does not appear to work just yet.
type FloatTensor[A] = Float[Tensor, A]


class SomeModule(nn.Module):
    def __init__(self, in_dims: int, out_dims: int, hidden_dims: int = 128):
        super().__init__()
        self.in_dims = in_dims
        self.hidden_dims = hidden_dims
        self.out_dims = out_dims
        self.linear1 = nn.Linear(in_dims, hidden_dims)
        self.linear2 = nn.Linear(hidden_dims, out_dims)
        self.activation = nn.ReLU()

    def forward(
        self, input: Float[Tensor, "b {self.in_dims}"]
    ) -> Float[Tensor, "b {self.out_dims}"]:
        return self.linear2(self.activation(self.linear1(input)))


@jaxtyped(typechecker=beartype)
def group_tokens(
    tokens: Float[Tensor, "b t vocab_dim"],
    block_size: int,
) -> Float[Tensor, "b num_blocks {block_size}*vocab_dim"]:
    return rearrange(
        tokens,
        "b (num_blocks block_size) vocab_dim -> b num_blocks (block_size vocab_dim)",
        block_size=block_size,
    )


@jaxtyped(typechecker=beartype)
def downsample_tokens(
    x: Float[Tensor, "b n*{k} d"], k: int
) -> Float[Tensor, "b n {k}*d"]:
    return rearrange(x, "b (n k) d -> b n (k d)", k=k)


def patchify(
    images: Float[Tensor, "b c h w"],
    p: int,
) -> Float[Tensor, " b (h/{p})*(w/{p}) ({p}*{p}*c)"]:
    return rearrange(images, "b c (hp p1) (wp p2) -> b (hp wp) (p1 p2 c)", p1=p, p2=p)


@jaxtyped(typechecker=beartype)
def patchify_wrong(
    images: Float32[Tensor, "b c h w"],
    p: int,
) -> Float32[Tensor, "b num_patches {p}*{p}*c"]:
    return torch.zeros(
        # correct shape:
        (
            images.shape[0],
            (images.shape[2] // p) * (images.shape[3] // p),
            # p * p * images.shape[1],
            123,
        ),
        dtype=torch.float32,
    )
    # return rearrange(images, "b c (h p1) (w p2) -> b (h w) (p1 p2 c)", p1=p, p2=p)


class MultiHeadSelfAttention(nn.Module):
    def __init__(self, embed_dim: int, num_heads: int):
        super().__init__()
        assert embed_dim % num_heads == 0
        self.h = num_heads
        self.d = embed_dim // num_heads
        self.qkv = nn.Linear(embed_dim, 3 * embed_dim)
        self.out = nn.Linear(embed_dim, embed_dim)

    @jaxtyped(typechecker=beartype)
    def forward(
        self,
        x: Float[Tensor, "b n {self.h}*{self.d}"],
    ) -> Float[Tensor, "b n {self.h}*{self.d}"]:
        q, k, v = rearrange(
            self.qkv(x),
            "b n (qkv h d) -> qkv b h n d",
            qkv=3,
            h=self.h,
        )
        attn = ((q @ k.transpose(-2, -1)) / self.d**0.5).softmax(dim=-1)
        out = rearrange(attn @ v, "b h n d -> b n (h d)")
        return self.out(out)


class SwiGLU(nn.Module):
    """SwiGLU feed-forward block: down(silu(gate) * up).

    Same shape in and out; expands to d_ff internally.
    Used in LLaMA, PaLM, Gemma — replaces the standard 2-layer ReLU MLP.
    """

    def __init__(self, d_model: int, d_ff: int):
        super().__init__()
        self.d_model = d_model
        self.d_ff = d_ff
        # Fused gate + up: one matmul instead of two, split with einops.
        self.gate_up = nn.Linear(d_model, 2 * d_ff, bias=False)
        self.down = nn.Linear(d_ff, d_model, bias=False)

    @jaxtyped(typechecker=beartype)
    def forward(
        self,
        x: Float[Tensor, "b n {self.d_model}"],
    ) -> Float[Tensor, "b n {self.d_model}"]:
        gate, up = rearrange(
            self.gate_up(x),
            "b n (two f) -> two b n f",
            two=2,
        )
        return self.down(F.silu(gate) * up)


# Accepts floating-point 2D arrays with matching axes
def matrix_multiply(
    x: Float[Tensor, "A B"], y: Float[Tensor, "B C"]
) -> Float[Tensor, "A C"]:
    return x @ y


Image = Float[jax.Array, "channels height width"]
ImageBatch = Float[Image, "batch"]
LabelsBatch = Integer[jax.Array, "batch"]

# def remove_last(x: Float[torch.Tensor, "dim"]) -> Float[torch.Tensor, "dim-1"]: ...


@dataclass
class Batch:
    x: ImageBatch
    y: Float[Tensor, "b c"]


if __name__ == "__main__":
    import torch

    images = torch.randn(2, 3, 4, 4)
    patches = patchify(images, p=2)
    print(patches.shape)  # torch.Size([2, 4, 12])`

    # # JaxTyping will raise because shapes are not correct):
    # images = torch.randn(2, 3, 4, 4)
    # patches = patchify_wrong(images, p=3)  # raises because 4 is not

    # test for the SwiGLU block:
    block = SwiGLU(d_model=16, d_ff=64)
    x = torch.randn(2, 10, 16)
    x = torch.randn(2, 102, 17)
    out = block(x)
    from jaxtyping import Float32

    assert isinstance(out, Float32[Tensor, "2 10 16"])  # torch.Size([2, 10, 16])
    assert isinstance(out, FloatTensor["2 10 16"])  # torch.Size([2, 10, 16])
