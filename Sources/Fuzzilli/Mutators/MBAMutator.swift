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
        let supportedOps : [BinaryOperator] = [.Sub, .Xor, .BitAnd, .Add, .BitOr]
        switch instr.op.opcode {
            case .binaryOperation(_):
                let myOpcode = instr.op as! BinaryOperation;
                return supportedOps.contains(myOpcode.op)
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

        let x = b.adopt(instr.input(0));
        let y = b.adopt(instr.input(1));
        
        switch myOpcode.op {
            case .Sub:
                mutateSub(x, y, b);
            case .Xor:
                mutateXor(x, y, b);
            case .Add:
                mutateAdd(x, y, b);
                break
            case .BitAnd:
                mutateBitAnd(x, y, b);
                break
            case .BitOr:
                mutateBitOr(x, y, b);
                break
            default:
                fatalError("Cannot handle \(instr) in MBAMutators::mutate()")
        }
        b.replace(old: instr.output, new: b.lastInstruction().output)
        // b.adopt(instr.output)
        // b.adopt(b.lastInstruction());
        
    }
    
    private func mutateSub(_ x: Variable, _ y: Variable, _ b: ProgramBuilder) {
        let num_variations = 1;
        switch Int.random(in: 0...num_variations) {
        case 0:
            // x - y = x + not(y) + 1
            // not(y)
            let notY = b.unary(.BitwiseNot, y)
            // x + not(y)
            let inter2 = b.binary(x, notY, with: .Add)
            // x + not(y) + 1
            // create an instruction
            // adopt output of old instruction to the next variable
            b.binary(inter2, b.loadInt(1), with: .Add)
        case 1:
            // (x^y)+2*(x|~y) + 2, x-y
            // (x^y)
            let inter1 = b.binary(x, y, with: .Xor)
            // 2*(x|~y)
            let notY = b.unary(.BitwiseNot, y)
            let inter2 = b.binary(x, notY, with: .BitOr)
            let inter3 = b.binary(b.loadInt(2), inter2, with: .Mul)
            // (x^y) + 2*(x|~y) + 2
            let inter4 = b.binary(inter1, inter3, with: .Add)
            b.binary(inter4, b.loadInt(2), with: .Add)
        default:
            fatalError("mutateSub: Not all cases between 0 and \(num_variations) are supported")
            
        }
        
    }
    
    private func mutateXor(_ x: Variable, _ y: Variable, _ b: ProgramBuilder) {
        let num_variations = 8;
        switch Int.random(in: 0...num_variations) {
        case 0:
            // (x|y)-y+(~x&y),x^y
            let notX = b.unary(.BitwiseNot, x)
            let inter2 = b.binary(x, y, with: .BitOr)           // (x|y)
            let inter3 = b.binary(notX, y, with: .BitAnd)       // (~x&y)
            let inter4 = b.binary(inter2, y, with: .Sub)        // (x|y)-y
            b.binary(inter4, inter3, with: .Add)                // (x|y)-y+(~x&y)
        case 1:
            // (x|y)-(~x|y)+(~x),x^y
            let notX = b.unary(.BitwiseNot, x)
            let inter2 = b.binary(x, y, with: .BitOr)           // (x|y)
            let inter3 = b.binary(notX, y, with: .BitOr)        // (~x|y)
            let inter4 = b.binary(inter2, inter3, with: .Sub)   // (x|y)-(~x|y)
            b.binary(inter4, notX, with: .Add)                  // (x|y)-(~x|y)+(~x)
        case 2:
            // (x|y)-(~x|y)+(~x),x^y
            let notX = b.unary(.BitwiseNot, x)
            let inter2 = b.binary(x, y, with: .BitOr)           // (x|y)
            let inter3 = b.binary(notX, y, with: .BitOr)        // (~x|y)
            let inter4 = b.binary(inter2, inter3, with: .Sub)   // (x|y)-(~x|y)
            b.binary(inter4, notX, with: .Add)                  // (x|y)-(~x|y)+(~x)
        case 3:
            // -(~x|y)+(~x&y)-1,x^y
            let notX = b.unary(.BitwiseNot, x)
            let inter2 = b.binary(notX, y, with: .BitOr)        // (~x|y)
            let inter3 = b.binary(notX, y, with: .BitAnd)       // (~x&y)
            let inter4 = b.binary(inter3, inter2, with: .Sub)   // -(~x|y)+(~x&y)
            b.binary(inter4, b.loadInt(1), with: .Sub)          // -(~x|y)+(~x&y)-1
        case 4:
            // 2*(x|y)-y-x,x^y
            let inter2 = b.binary(x, y, with: .BitOr)               // (x|y)
            let inter3 = b.binary(b.loadInt(2), inter2, with: .Mul) // 2*(x|y)
            let inter4 = b.binary(inter3, y, with: .Sub)            // 2*(x|y)-y
            b.binary(inter4, x, with: .Sub)                         // 2*(x|y)-y-x
        case 5:
            // -(~x|y)-(x|~y)-2,x^y
            let notX = b.unary(.BitwiseNot, x)
            let notY = b.unary(.BitwiseNot, y)
            let inter2 = b.binary(notX, y, with: .BitOr)                // (~x|y)
            let inter3 = b.binary(notY, x, with: .BitOr)                // (x|~y)
            let inter4 = b.binary(b.loadInt(0), inter2, with: .Sub)     // -(~x|y)
            let inter5 = b.binary(inter4, inter3, with: .Sub)           // -(~x|y)-(x|~y)
            b.binary(inter5, b.loadInt(2), with: .Sub)                  // -(~x|y)-(x|~y)-2
        case 6:
            // -y+2*(~x&y)+x,x^y
            let notX = b.unary(.BitwiseNot, x)                          // ~x
            let inter2 = b.binary(notX, y, with: .BitAnd)               // (~x&y)
            let inter3 = b.binary(b.loadInt(2), inter2, with: .Mul)     // 2*(~x&y)
            let inter4 = b.binary(inter3, y, with: .Sub)                // 2*(~x&y)-y
            b.binary(inter4, x, with: .Add)                             // -y+2*(~x&y)+x
        case 7:
            // x-y - 2*(x|~y)-2, x^y
            let notY = b.unary(.BitwiseNot, y)
            let inter2 = b.binary(notY, x, with: .BitOr)                // (x|~y)
            let inter3 = b.binary(b.loadInt(2), inter2, with: .Mul)     // 2*(x|~y)
            let inter4 = b.binary(x, y, with: .Sub)                     // x-y
            let inter5 = b.binary(inter4, inter3, with: .Sub)           // x-y - 2*(x|~y)
            b.binary(inter5, b.loadInt(2), with: .Sub)                  // x-y - 2*(x|~y)-2
        case 8:
            // -(~x|y)+2*(~x&y)+(x|~y),x^y
            let notX = b.unary(.BitwiseNot, x)
            let notY = b.unary(.BitwiseNot, y)
            let inter2 = b.binary(notX, y, with: .BitOr)                // (~x|y)
            let inter3 = b.binary(notY, x, with: .BitOr)                // (x|~y)
            let inter4 = b.binary(notX, y, with: .BitAnd)               // (~x&y)
            let inter5 = b.binary(b.loadInt(2), inter4, with: .Mul)     // 2*(~x&y)
            let inter6 = b.binary(inter5, inter2, with: .Sub)           // 2*(~x&y)-(~x|y)
            b.binary(inter6, inter3, with: .Add)                        // -(~x|y)+2*(~x&y)+(x|~y)
        default:
            fatalError("mutateXor: Not all cases between 0 and \(num_variations) are supported")
        }
        // TODO: Implement the following
        // y+(x&~y)-(x&y),x^y
        // y+(~y)-~(x^y),x^y
        // (~x|y)+(x&~y)-~(x^y),x^y
        // -(x|~y)+(~x|y)-2*(~(x|y))+2*(~y),x^y
        // (x|~y)-3*(~(x|y))+2*(~x)-y,x^y
        // -(x|~y)+(~y)+(x&~y)+y,x^y
        // (x|~y)+(~x|y)-2*(~(x|y))-2*(x&y),x^y
        // (x|y)-(~x|y)+(~x),x^y
        // 2*y-(~x)+(~y),x+y
        // 2*(x|y)-y-x,x^y
        // -(~x|y)+2*(~x&y)+(x|~y),x^y
        // (~x|y)+(x&~y)-~(x^y),x^y
        // -(x|~y)+(~y)+(x&~y)+y,x^y
        // (x|~y)+(~x|y)-2*(~(x|y))-2*(x&y),x^y

    }
    
    private func mutateAdd(_ x: Variable, _ y: Variable, _ b: ProgramBuilder) {
        let num_variations = 7;
        switch Int.random(in: 0...num_variations) {
        case 0:
            // (x|y)+y-(~x&y),x+y
            let notX = b.unary(.BitwiseNot, x)
            let inter2 = b.binary(x, y, with: .BitOr)           // (x|y)
            let inter3 = b.binary(notX, y, with: .BitAnd)       // (~x&y)
            let inter4 = b.binary(inter2, y, with: .Add)        // (x|y)+y
            b.binary(inter4, inter3, with: .Sub)                // (x|y)+y-(~x&y)
        case 1:
            // (x|y)+(~x|y)-(~x),x+y
            let notX = b.unary(.BitwiseNot, x)
            let inter2 = b.binary(x, y, with: .BitOr)           // (x|y)
            let inter3 = b.binary(notX, y, with: .BitOr)        // (~x|y)
            let inter4 = b.binary(inter2, inter3, with: .Add)   // (x|y)+(~x|y)
            b.binary(inter4, notX, with: .Sub)                  // (x|y)+(~x|y)-(~x)
        case 2:
            // y-(~x)-1,x+y
            let notX = b.unary(.BitwiseNot, x)
            let inter2 = b.binary(y, notX, with: .Sub)
            b.binary(inter2, b.loadInt(1), with: .Sub)
        case 3:
            // 2*(x|y)-(~x&y)-(x&~y),x+y
            let notX = b.unary(.BitwiseNot, x)
            let notY = b.unary(.BitwiseNot, y)
            let inter2 = b.binary(x, y, with: .BitOr)
            let inter3 = b.binary(b.loadInt(2), inter2, with: .Mul)
            let inter4 = b.binary(notX, y, with: .BitAnd)
            let inter5 = b.binary(x, notY, with: .BitAnd)
            let inter6 = b.binary(inter3, inter4, with: .Sub)
            let inter7 = b.binary(inter6, inter5, with: .Sub)
        case 4:
            // -(~x)-(~y)-2,x+y
            let notX = b.unary(.BitwiseNot, x)
            let notY = b.unary(.BitwiseNot, y)
            let inter2 = b.binary(b.loadInt(0), notX, with: .Sub)
            let inter3 = b.binary(inter2, notY, with: .Sub)
            b.binary(inter3, b.loadInt(2), with: .Sub)
        case 5:
            // (x^y)+2*y-2*(~x&y),x+y
            let notX = b.unary(.BitwiseNot, x)
            let inter2 = b.binary(x, y, with: .Xor)
            let inter3 = b.binary(y, b.loadInt(2), with: .Mul)
            let inter4 = b.binary(notX, y, with: .BitAnd)
            let inter5 = b.binary(b.loadInt(2), inter4, with: .Mul)
            let inter6 = b.binary(inter2, inter3, with: .Add)
            let inter7 = b.binary(inter6, inter5, with: .Sub)
        case 6:
            // (x^y)+2*(~x|y)-2*(~x),x+y
            let notX = b.unary(.BitwiseNot, x)
            let inter2 = b.binary(x, y, with: .Xor)                 // (x^y)
            let inter3 = b.binary(notX, y, with:.BitOr)             // (~x|y)
            let inter4 = b.binary(b.loadInt(2), inter3, with: .Mul) // 2*(~x|y)
            let inter5 = b.binary(b.loadInt(2), notX, with: .Mul)   // 2*(~x)
            let inter6 = b.binary(inter2, inter4, with: .Add)       // (x^y)+2*(~x|y)
            b.binary(inter6, inter5, with: .Sub)                    // (x^y)+2*(~x|y)-2*(~x)
        case 7:
            // -(x^y)+2*y+2*(x&~y),x+y
            let notY = b.unary(.BitwiseNot, y)
            let inter2 = b.binary(x, y, with: .Xor)                 // (x^y)
            let inter3 = b.binary(b.loadInt(2), y, with: .Mul)      // 2*y
            let inter4 = b.binary(x, notY, with: .BitAnd)           // (x&~y)
            let inter5 = b.binary(b.loadInt(2), inter4, with: .Mul) // 2*(x&~y)
            let inter6 = b.binary(inter3, inter2, with: .Sub)       // -(x^y)+2*y
            b.binary(inter5, inter6, with: .Add)                    // -(x^y)+2*y+2*(x&~y)
        default:
            fatalError("mutateAdd: Not all cases between 0 and \(num_variations) are supported")
        }
        // TODO: Implement the following
        // 2*y-(~x&y)+(x&~y),x+y
        // 2*y-(~x)+(~y),x+y
        // y+(x&~y)+(x&y),x+y
        // (~x&y)+(x&~y)+2*(x&y),x+y
        // 3*(x|~y)+(~x|y)-2*(~y)-2*(~(x^y)),x+y
        // -(x|~y)-(~x)+(x&y)-2,x+y
        // (x|~y)+(~x&y)-(~(x&y))+(x|y),x+y
        // 2*(~(x^y))+3*(~x&y)+3*(x&~y)-2*(~(x&y)),x+y
        // -(x^y)+2*y+2*(x&~y),x+y
    }
    
    private func mutateBitAnd(_ x: Variable, _ y: Variable, _ b: ProgramBuilder) {
        let num_variations = 1;
        switch Int.random(in: 0...num_variations) {
        case 0:
            // -(x|y)+x+y,x&y
            let inter2 = b.binary(x, y, with: .BitOr)           // (x|y)
            let inter3 = b.binary(x, inter2, with: .Sub)        // -(x|y)+x
            b.binary(inter3, y, with: .Add)                     // -(x|y)+x+y
        case 1:
            // (x|~y)+y+1,x&y
            let notY = b.unary(.BitwiseNot, y)
            let inter2 = b.binary(x, notY, with: .BitOr)        // (x|~y)
            let inter3 = b.binary(inter2, y, with: .BitOr)      // (x|~y)+y
            b.binary(inter3, b.loadInt(1), with: .Add)          // (x|~y)+y+1
        default:
            fatalError("mutateAdd: Not all cases between 0 and \(num_variations) are supported")
        }
        // TODO: Implement the following
        // (x|y)-(~x&y)-(x&~y),x&y
        // -(~x&y)-(~y)-1,x&y
        // -(x^y)+y+(x&~y),x&y
        // -~(x&y)+y+~y,x&y
        // -~(x&y)+(~x|y)+(x&~y),x&y
        // (x|y)-(~x&y)-(x&~y),x&y

    }
    
    private func mutateBitOr(_ x: Variable, _ y: Variable, _ b: ProgramBuilder) {
        let num_variations = 1;
        switch Int.random(in: 0...num_variations) {
        case 0:
            // (x^y)+y-(~x&y),x|y
            let notX = b.unary(.BitwiseNot, x)
            let inter2 = b.binary(x, y, with: .Xor)             // (x^y)
            let inter3 = b.binary(notX, y, with: .BitAnd)       // (~x&y)
            let inter4 = b.binary(inter2, y, with: .Add)        // (x^y)+y
            b.binary(inter4, inter3, with: .Sub)                // (x^y)+y-(~x&y)
        case 1:
            // (x^y)+(~x|y)-(~x),x|y
            let notX = b.unary(.BitwiseNot, x)
            let inter2 = b.binary(x, y, with: .Xor)             // (x^y)
            let inter3 = b.binary(notX, y, with: .BitOr)        // (~x|y)
            let inter4 = b.binary(inter2, inter3, with: .Add)   // (x^y)+(~x|y)
            b.binary(inter4, notX, with: .Sub)                  // (x^y)+(~x|y)-(~x)
        default:
            fatalError("mutateAdd: Not all cases between 0 and \(num_variations) are supported")
        }
        // TODO: Implement the following
        // ~(x&y)+y-(~x),x|y
        // x+y-(x&y),x|y
        // y+(x|~y)-(~(x^y)),x|y
        // (~x&y)+(x&~y)+(x&y),x|y

    }
}
