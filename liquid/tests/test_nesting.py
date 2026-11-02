"""Braze renders a Content Block inside another block only one level deep, and removes anything deeper.

Braze's Content Blocks docs say: "Content Blocks can be nested, but only once." A third level is
removed from the message. So every chain that starts at a message may hold at most two blocks:
message -> block -> block.
"""
import re

import pytest

from harness import BLOCKS, LIQUID_DIR

MAX_LEVELS = 2
INCLUDE = re.compile(r"\{\{content_blocks\.\$\{(\w+)\}\}\}")
MESSAGES = sorted((LIQUID_DIR / "messages").glob("*.liquid"))


def chains(source, blocks=BLOCKS, prefix=()):
    """Every chain of block names reachable from source, outermost first."""
    for name in INCLUDE.findall(source):
        if name in prefix:
            raise AssertionError(f"Content Block cycle: {' -> '.join(prefix + (name,))}")
        chain = prefix + (name,)
        yield chain
        yield from chains(blocks[name], blocks, chain)


def describe(chain):
    return " -> ".join(("message",) + chain)


@pytest.mark.parametrize("path", MESSAGES, ids=lambda p: p.name)
def test_no_block_chain_goes_deeper_than_two(path):
    too_deep = [c for c in chains(path.read_text(encoding="utf-8")) if len(c) > MAX_LEVELS]
    assert not too_deep, "Braze would drop: " + "; ".join(describe(c) for c in too_deep)


def test_the_check_catches_a_three_level_chain():
    blocks = {"a": "{{content_blocks.${b}}}", "b": "{{content_blocks.${c}}}", "c": "text"}
    deep = [c for c in chains("{{content_blocks.${a}}}", blocks) if len(c) > MAX_LEVELS]
    assert deep == [("a", "b", "c")]
