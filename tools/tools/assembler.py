#!/usr/bin/env python3
"""Assembler for the Simple 8-bit CPU ISA.

Supported mnemonics:
  - HALT
  - ADD rd, rs1, rs2
  - SUB rd, rs1, rs2
  - AND rd, rs1, rs2
  - OR  rd, rs1, rs2
  - BEQ rs1, rs2, label_or_offset
  - BNE rs1, rs2, label_or_offset

Encoding:
  R-type:  [15:12] opcode | [11:9] rd  | [8:6] rs1 | [5:3] rs2 | [2:0] 0
  Branch:  [15:12] opcode | [11:9] rs1 | [8:6] rs2 | [5:0] signed offset
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
from dataclasses import dataclass
from typing import Dict, List, Sequence, Tuple


OPCODES = {
	"HALT": 0x0,
	"ADD": 0x1,
	"SUB": 0x2,
	"AND": 0x3,
	"OR": 0x4,
	"BEQ": 0x5,
	"BNE": 0x6,
	"ADDI": 0x7,
	"LW": 0x8,
	"SW": 0x9,
	"JMP": 0xA,
}

R_TYPE = {"ADD", "SUB", "AND", "OR"}
BR_TYPE = {"BEQ", "BNE"}
J_TYPE = {"JMP"}
I_TYPE = {"ADDI", "LW"}
S_TYPE = {"SW"}

COMMENT_MARKERS = ("//", "#", ";")
LABEL_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


@dataclass(frozen=True)
class ParsedLine:
	pc: int
	source_line: int
	text: str
	mnemonic: str
	operands: Tuple[str, ...]


class AssemblerError(Exception):
	"""Raised for assembler input and encoding errors."""


def strip_comment(line: str) -> str:
	trimmed = line
	for marker in COMMENT_MARKERS:
		idx = trimmed.find(marker)
		if idx != -1:
			trimmed = trimmed[:idx]
	return trimmed.strip()


def parse_register(token: str, source_line: int) -> int:
	token = token.strip().upper()
	if not token.startswith("R"):
		raise AssemblerError(f"Line {source_line}: expected register token, got '{token}'.")
	idx_text = token[1:]
	if not idx_text.isdigit():
		raise AssemblerError(f"Line {source_line}: malformed register '{token}'.")
	idx = int(idx_text, 10)
	if idx < 0 or idx > 7:
		raise AssemblerError(f"Line {source_line}: register out of range '{token}' (allowed R0..R7).")
	return idx


def parse_int(token: str, source_line: int) -> int:
	token = token.strip()
	try:
		return int(token, 0)
	except ValueError as exc:
		raise AssemblerError(f"Line {source_line}: invalid integer '{token}'.") from exc


def split_operands(operand_text: str) -> Tuple[str, ...]:
	if not operand_text.strip():
		return tuple()
	return tuple(part.strip() for part in operand_text.split(",") if part.strip())


def parse_source(lines: Sequence[str]) -> Tuple[List[ParsedLine], Dict[str, int]]:
	parsed: List[ParsedLine] = []
	labels: Dict[str, int] = {}
	pc = 0

	for idx, raw in enumerate(lines, start=1):
		line = strip_comment(raw)
		if not line:
			continue

		working = line
		while ":" in working:
			left, right = working.split(":", 1)
			label = left.strip()
			if not label:
				raise AssemblerError(f"Line {idx}: empty label before ':'.")
			if not LABEL_RE.match(label):
				raise AssemblerError(f"Line {idx}: invalid label '{label}'.")
			if label in labels:
				raise AssemblerError(f"Line {idx}: duplicate label '{label}'.")
			labels[label] = pc
			working = right.strip()
			if not working:
				break

		if not working:
			continue

		parts = working.split(None, 1)
		mnemonic = parts[0].upper()
		if mnemonic not in OPCODES:
			raise AssemblerError(f"Line {idx}: unknown mnemonic '{mnemonic}'.")

		operand_text = parts[1] if len(parts) > 1 else ""
		operands = split_operands(operand_text)
		parsed.append(
			ParsedLine(
				pc=pc,
				source_line=idx,
				text=working,
				mnemonic=mnemonic,
				operands=operands,
			)
		)
		pc += 1

	return parsed, labels


def encode_rtype(opcode: int, rd: int, rs1: int, rs2: int) -> int:
	return (opcode << 12) | (rd << 9) | (rs1 << 6) | (rs2 << 3)


def encode_itype(opcode: int, rd: int, rs1: int, imm6: int) -> int:
	if imm6 < -32 or imm6 > 31:
		raise AssemblerError(
			f"Immediate {imm6} out of range for signed 6-bit field (-32..31)."
		)
	return (opcode << 12) | (rd << 9) | (rs1 << 6) | (imm6 & 0x3F)


def encode_branch(opcode: int, rs1: int, rs2: int, offset: int) -> int:
	if offset < -32 or offset > 31:
		raise AssemblerError(
			f"Branch offset {offset} out of range for signed 6-bit field (-32..31)."
		)
	return (opcode << 12) | (rs1 << 9) | (rs2 << 6) | (offset & 0x3F)


def resolve_branch_target(token: str, labels: Dict[str, int], source_line: int) -> int:
	if LABEL_RE.match(token):
		if token not in labels:
			raise AssemblerError(f"Line {source_line}: unknown label '{token}'.")
		return labels[token]
	return parse_int(token, source_line)


def assemble(parsed: Sequence[ParsedLine], labels: Dict[str, int]) -> List[Tuple[int, ParsedLine]]:
	encoded: List[Tuple[int, ParsedLine]] = []
	for line in parsed:
		mnemonic = line.mnemonic
		op = OPCODES[mnemonic]
		ops = line.operands

		if mnemonic == "HALT":
			if ops:
				raise AssemblerError(f"Line {line.source_line}: HALT takes no operands.")
			encoded.append((op << 12, line))
			continue

		if mnemonic in R_TYPE:
			if len(ops) != 3:
				raise AssemblerError(
					f"Line {line.source_line}: {mnemonic} expects 3 operands (rd, rs1, rs2)."
				)
			rd = parse_register(ops[0], line.source_line)
			rs1 = parse_register(ops[1], line.source_line)
			rs2 = parse_register(ops[2], line.source_line)
			encoded.append((encode_rtype(op, rd, rs1, rs2), line))
			continue

		if mnemonic in BR_TYPE:
			if len(ops) != 3:
				raise AssemblerError(
					f"Line {line.source_line}: {mnemonic} expects 3 operands (rs1, rs2, target)."
				)
			rs1 = parse_register(ops[0], line.source_line)
			rs2 = parse_register(ops[1], line.source_line)
			target = resolve_branch_target(ops[2], labels, line.source_line)
			offset = target - (line.pc + 1)
			encoded.append((encode_branch(op, rs1, rs2, offset), line))
			continue

		if mnemonic in I_TYPE:  # ADDI rd, rs1, imm  /  LW rd, rs1, imm
			if len(ops) != 3:
				raise AssemblerError(
					f"Line {line.source_line}: {mnemonic} expects 3 operands (rd, rs1, imm)."
				)
			rd = parse_register(ops[0], line.source_line)
			rs1 = parse_register(ops[1], line.source_line)
			imm6 = parse_int(ops[2], line.source_line)
			encoded.append((encode_itype(op, rd, rs1, imm6), line))
			continue

		if mnemonic in J_TYPE:  # JMP label_or_offset
			if len(ops) != 1:
				raise AssemblerError(
					f"Line {line.source_line}: {mnemonic} expects 1 operand (target)."
				)
			target = resolve_branch_target(ops[0], labels, line.source_line)
			offset = target - (line.pc + 1)
			encoded.append((encode_branch(op, 0, 0, offset), line))
			continue

		if mnemonic in S_TYPE:  # SW rs2, rs1, imm
			if len(ops) != 3:
				raise AssemblerError(
					f"Line {line.source_line}: {mnemonic} expects 3 operands (rs2, rs1, imm)."
				)
			rs2 = parse_register(ops[0], line.source_line)
			rs1 = parse_register(ops[1], line.source_line)
			imm6 = parse_int(ops[2], line.source_line)
			# SW encoding: [11:9]=rs2(data), [8:6]=rs1(base), [5:0]=imm6
			encoded.append((encode_itype(op, rs2, rs1, imm6), line))
			continue

		raise AssemblerError(f"Line {line.source_line}: unsupported mnemonic '{mnemonic}'.")

	return encoded


def format_hex(encoded: Sequence[Tuple[int, ParsedLine]], include_comments: bool) -> str:
	lines: List[str] = []
	for word, parsed in encoded:
		if include_comments:
			lines.append(f"{word:04X}  // PC={parsed.pc}: {parsed.text}")
		else:
			lines.append(f"{word:04X}")
	return "\n".join(lines) + "\n"


def format_listing(encoded: Sequence[Tuple[int, ParsedLine]]) -> str:
	out = ["PC   HEX   SOURCE"]
	for word, parsed in encoded:
		out.append(f"{parsed.pc:03d}  {word:04X}  {parsed.text}")
	return "\n".join(out) + "\n"


def build_arg_parser() -> argparse.ArgumentParser:
	parser = argparse.ArgumentParser(description="Assemble Simple 8-bit CPU assembly into HEX.")
	parser.add_argument("input", type=pathlib.Path, help="Input .asm file")
	parser.add_argument("-o", "--output", type=pathlib.Path, required=True, help="Output .hex file")
	parser.add_argument(
		"--no-comments",
		action="store_true",
		help="Write HEX without source comments.",
	)
	parser.add_argument(
		"--listing",
		type=pathlib.Path,
		default=None,
		help="Optional listing file (PC/HEX/source).",
	)
	return parser


def main(argv: Sequence[str] | None = None) -> int:
	parser = build_arg_parser()
	args = parser.parse_args(argv)

	try:
		source_text = args.input.read_text(encoding="utf-8")
		parsed, labels = parse_source(source_text.splitlines())
		encoded = assemble(parsed, labels)
		hex_text = format_hex(encoded, include_comments=not args.no_comments)

		args.output.parent.mkdir(parents=True, exist_ok=True)
		args.output.write_text(hex_text, encoding="utf-8")

		if args.listing is not None:
			args.listing.parent.mkdir(parents=True, exist_ok=True)
			args.listing.write_text(format_listing(encoded), encoding="utf-8")

		print(f"Assembled {len(encoded)} instructions: {args.input} -> {args.output}")
		return 0
	except AssemblerError as exc:
		print(f"Assembly error: {exc}", file=sys.stderr)
		return 1
	except OSError as exc:
		print(f"File error: {exc}", file=sys.stderr)
		return 1


if __name__ == "__main__":
	raise SystemExit(main())

