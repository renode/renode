from typing import Tuple, List
from enum import Enum
from argparse import ArgumentParser, BooleanOptionalAction
from dataclasses import dataclass

import random
import mve_helpers as mve

Q_REGISTER_SIZE = 128


# ===== Saturation instructions generation =====
# Saturation results can end up in one of three states after instruction, they can end up in their value range, end up above it or below it
class SaturationResultState(Enum):
    InRange = 0
    BelowMinimum = 1
    AboveMaximum = 2


class GenerationError(ValueError):
    """Error type that occurs when given generation parameters can't generate expected case"""


@dataclass
class SaturationInstruction:
    name: str
    is_signed: int
    element_size: int
    scalar: bool

    def generate_element_first_operand(
        self, result_state: SaturationResultState
    ) -> int:
        """
        Generates first operand for the instruction element. The operand is picked so that it's possible to reach specified result after processing it with the second operand.

        :param result_state: state that must be achievable if generated operand
        """
        pass

    def generate_element(
        self, op1: int | None, result_state: SaturationResultState
    ) -> Tuple[int, int, int, bool]:
        """
        Generates operands and result of the instruction.

        :param op1: pre-generated first operand for the instruction. It should be generated with the same result_state as used here
        """
        pass

    def compute(self, op1: int, op2: int) -> Tuple[int, bool]:
        """
        Computes the result of the instruction based on given operands.
        """
        pass


@dataclass
class SaturationCase:
    """Whole instruction case with instruction operands and result"""

    operand1: str
    operand2: str
    result: str
    saturated: bool
    instruction: SaturationInstruction


def convert_to_robot(cases: List[SaturationCase]) -> str:
    """Converts given cases to piece of robot framework code"""
    text = ""
    for case in cases:
        if isinstance(case, SaturationCase):
            insn = case.instruction
            text += f"""
    Saturated Vector-{"Scalar" if insn.scalar else "Vector"} {insn.name}.{"s" if insn.is_signed else "u"}{insn.element_size} Should Produce Correct Result
    ...    operand1={case.operand1}  operand2={case.operand2}  result={case.result}  got_saturated={case.saturated}
    """
        elif isinstance(case, str):
            text += f"# {case}"
        else:
            raise ValueError("Can't convert specified value type")

    return text


def generate_saturation_cases(
    insn_name: str,
    skip_impossible: bool = False,
) -> str:
    cases = []
    for is_signed in [True, False]:
        for element_size in [8, 16, 32]:
            for scalar in [True, False]:
                insn = SATURATION_CLASSES[insn_name](
                    name=insn_name,
                    is_signed=is_signed,
                    element_size=element_size,
                    scalar=scalar,
                )
                for result_state in SaturationResultState:
                    try:
                        cases.append(
                            generate_single_saturation_case(insn, result_state)
                        )
                    except GenerationError as e:
                        if not skip_impossible:
                            cases.append(
                                f"Can't achieve {result_state} with {insn.name}.{'s' if insn.is_signed else 'u'}{insn.element_size}"
                            )
    return convert_to_robot(cases)


def generate_single_saturation_case(
    insn: SaturationInstruction, result_state: SaturationResultState = None
) -> SaturationCase:
    _, int_to_hex, _ = mve.prepare_vector_op(insn.element_size, insn.is_signed)
    scalar = None
    if insn.scalar:
        # We're using same operand for all elements
        scalar = insn.generate_element_first_operand(result_state)

    out = []
    if result_state == None:
        # Populate with random result states
        if scalar != None:
            raise GenerationError(
                "Can't generate result with different states for one scalar"
            )
        for _ in range(0, (Q_REGISTER_SIZE // insn.element_size)):
            out.append(
                insn.generate_element(
                    scalar, random.choice(list(SaturationResultState))
                )
            )
    else:
        for _ in range(0, (Q_REGISTER_SIZE // insn.element_size)):
            out.append(insn.generate_element(scalar, result_state))

    # Scalar needs to go as second operand, that's why we swap it with first
    if insn.scalar:
        op2 = int_to_hex(scalar)
    else:
        op2 = mve.combine_n_into_128_bit_value(
            insn.element_size, [int_to_hex(o[0]) for o in out]
        )
    op1 = mve.combine_n_into_128_bit_value(
        insn.element_size, [int_to_hex(o[1]) for o in out]
    )
    res = mve.combine_n_into_128_bit_value(
        insn.element_size, [int_to_hex(o[2]) for o in out]
    )
    sat = any([o[3] for o in out])

    case = SaturationCase(
        instruction=insn, operand1=op1, operand2=op2, result=res, saturated=sat
    )
    return case


SATURATION_CLASSES = {
}


if __name__ == "__main__":
    parser = ArgumentParser(description="Generates cases for arm-cortex-m-mve.robot")
    parser.add_argument(
        "instruction", help="name of the instruction to generate cases for"
    )
    parser.add_argument("--seed", help="seed for the generator")
    parser.add_argument(
        "--validate",
        action=BooleanOptionalAction,
        help="add comment to robot when generating impossible case",
    )
    args = parser.parse_args()
    if args.seed:
        random.seed(args.seed)
    print(generate_saturation_cases(args.instruction, not args.validate))
