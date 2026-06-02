#!/usr/bin/env python3
"""unsloth-demo — verify the CUDA fine-tuning stack on this host.

Prints the version of every component, asserts an NVIDIA GPU is visible to
torch, and (optionally, behind UNSLOTH_DEMO_TRAIN=1) runs a tiny LoRA sanity
step. The training path is OFF by default so `nix run` works on any NVIDIA host
without pulling a multi-gigabyte model from Hugging Face.
"""

from __future__ import annotations

import importlib
import os
import sys


def _version(module: str) -> str:
    try:
        return getattr(importlib.import_module(module), "__version__", "unknown")
    except Exception as exc:  # noqa: BLE001 — report, don't crash the banner
        return f"<import error: {exc}>"


STACK = [
    "torch",
    "transformers",
    "peft",
    "trl",
    "datasets",
    "accelerate",
    "bitsandbytes",
    "triton",
    "xformers",
    "sentencepiece",
    "huggingface_hub",
    "unsloth",
    "unsloth_zoo",
]


def main() -> int:
    import torch

    print("=== unsloth-nix stack ===")
    for module in STACK:
        print(f"  {module:16} {_version(module)}")

    if not torch.cuda.is_available():
        print(
            "\ntorch.cuda.is_available() is False — build/run the CUDA env "
            "(`nix run .`) on an NVIDIA host. For AMD use `nix build .#rocm`.",
            file=sys.stderr,
        )
        return 1

    print(f"  CUDA device      {torch.cuda.get_device_name(0)}")
    print(f"  CUDA capability  {torch.cuda.get_device_capability(0)}")

    if os.environ.get("UNSLOTH_DEMO_TRAIN") != "1":
        print("\nSkipping LoRA sanity step (set UNSLOTH_DEMO_TRAIN=1 to run it).")
        return 0

    # Guarded tiny LoRA sanity. Downloads a small model from Hugging Face.
    print("\nLoading a tiny model with Unsloth (FastLanguageModel)…")
    from unsloth import FastLanguageModel

    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=os.environ.get("UNSLOTH_DEMO_MODEL", "unsloth/Qwen2.5-0.5B"),
        max_seq_length=512,
        load_in_4bit=True,
    )
    FastLanguageModel.get_peft_model(model, r=8, lora_alpha=16)
    print("LoRA adapters attached - environment is functional.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
