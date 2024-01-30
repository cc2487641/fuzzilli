// Mutate binary expressions to their equivalent MBA expressions, 
// e.g. https://www.usenix.org/system/files/sec21fall-liu-binbin.pdf
// x - y = x + not(y) + 1
// x XOR y = ( x AND y ) - ( x OR y )

/// Base class for mutators that operate on or at single instructions.
public class MBAMutator: BaseInstructionMutator {


    public init() {
        super.init(maxSimultaneousMutations: defaultMaxSimultaneousMutations)
    }

    /// Overridden by child classes.
    /// Determines the set of instructions that can be mutated by this mutator
    public override func canMutate(_ instr: Instruction, _ builder: ProgramBuilder) -> Bool {

        // for now, we only mutate x - y and x XOR y 
        // TODO: need to check that x and y are both integers
        switch instr.op.opcode {
            case .binaryOperation(_):
                let myOpcode = instr.op as! BinaryOperation;
                return (myOpcode.op == .Sub)
                // (builder.type(of: instr.input(0)) == .integerOnly) &&
                // (builder.type(of: instr.input(1)) == .integerOnly) &&
                // (builder.type(of: instr.output) == .integerOnly)
            default:
                return false;
        }

    }

    /// Overridden by child classes.
    /// Mutate a single statement
    public override func mutate(_ instr: Instruction, _ b: ProgramBuilder) {
        // b.adopt(instr)
        let myStr = FuzzILLifter().lift(Code([instr]))
        let myOpcode = instr.op as! BinaryOperation;

        switch myOpcode.op {
            case .Sub:
                // x - y = x + not(y) + 1
                let x = instr.input(0);
                let y = instr.input(1);
                // not(y)
                let notY = b.unary(.BitwiseNot, y)
                // x + not(y)
                let inter2 = b.binary(x, notY, with: .Add)
                // x + not(y) + 1
                // create an instruction
                // adopt output of old instruction to the next variable
                b.binary(inter2, b.loadInt(1), with: .Add)
            default:
                fatalError("Cannot handle \(instr) in MBAMutators::mutate()")
        }
        b.replace(old: instr.output, new: b.lastInstruction().output)
        //b.adopt(b.lastInstruction());
        
    }
}
