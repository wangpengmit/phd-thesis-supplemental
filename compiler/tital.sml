(* Timed and Typed Assembly Language *)

structure TiTAL = struct

open MicroTiML
open Binders

type reg = int
type label = int

datatype word_const =
         WCTT
         | WCNat of nat
         | WCInt of int
         | WCBool of bool
         | WCiBool of bool
         | WCByte of Char.char

(* atomic word values *)
datatype 'ty word =
         WLabel of label
         | WConst of word_const
         | WUninit of 'ty
         | WBuiltin of string * 'ty
         | WNever of 'ty
           
(* small values *)
datatype ('idx, 'ty) value =
         VReg of reg
         | VWord of 'ty word
         | VAppT of ('idx, 'ty) value * 'ty
         | VAppI of ('idx, 'ty) value * 'idx
         | VPack of 'ty * 'ty * ('idx, 'ty) value
         | VPackI of 'ty * 'idx * ('idx, 'ty) value
         | VFold of 'ty * ('idx, 'ty) value
         | VAscType of ('idx, 'ty) value * 'ty

datatype inst_un_op =
         IUMov
         | IUBrSum
         | IUBrI
         | IUBrBool
         | IUUnfold
         | IUPrim of prim_expr_un_op
         | IUArrayLen
         | IUNat2Int
         | IUInt2Nat
         | IUPrintc
         (* | IUPrint *)
             
datatype inst_bin_op =
         IBPrim of prim_expr_bin_op
         | IBNat of nat_expr_bin_op
         | IBNatCmp of nat_cmp
         | IBNew
         | IBRead
         | IBWrite
             
datatype ('idx, 'ty) inst =
         IUnOp of inst_un_op * reg * ('idx, 'ty) value inner
         | IBinOp of inst_bin_op * reg * reg * ('idx, 'ty) value inner
         | IMallocPair of reg * (('idx, 'ty) value inner * ('idx, 'ty) value inner)
         | ILd of reg * (reg * projector)
         | ISt of (reg * projector) * reg
         | IUnpack of tbinder * reg * ('idx, 'ty) value outer
         | IUnpackI of ibinder * reg * ('idx, 'ty) value outer
         | IInj of reg * injector * ('idx, 'ty) value inner * 'ty inner
         | IAscTime of 'idx inner
         | INewArrayValues of reg * 'ty inner * ('idx, 'ty) value inner list (* the ability to take unlimited number of arguments is a bit unrealistic for an instruction *)
         (* | IString of reg * string *)

datatype ('idx, 'ty) insts =
         ISCons of (('idx, 'ty) inst, ('idx, 'ty) insts) bind
         | ISJmp of ('idx, 'ty) value
         | ISHalt of 'ty
         (* only for debug/printing purpose *)
         | ISDummy of string

type 'v rctx = 'v IntBinaryMap.map
                  
type ('idx, 'sort, 'kind, 'ty) hval = ((ibinder * 'sort outer, tbinder * 'kind) sum tele, ('ty rctx * 'idx) * ('idx, 'ty) insts) bind

infixr 0 $
         
fun VConst a = VWord $ WConst a
fun VLabel a = VWord $ WLabel a
fun VNever a = VWord $ WNever a
fun VBuiltin a = VWord $ WBuiltin a

fun VAppIT (e, arg) =
    case arg of
        inl i => VAppI (e, i)
      | inr t => VAppT (e, t)
fun VAppITs (f, args) = foldl (swap VAppIT) f args
                     
infixr 5 @::
infixr 5 @@
infix  6 @+
infix  9 @!
         
fun a @:: b = ISCons $ Bind (a, b)
fun ls @@ b = foldr (op@::) b ls 
fun m @+ a = Rctx.insert' (a, m)
fun m @! k = Rctx.find (m, k)
                        
fun HCode' (binds, body) =
  Bind (Teles $ map (map_inl_inr (fn (name, s) => (IBinder name, Outer s)) (fn (name, k) => (TBinder name, k))) binds, body)

val IBNatAdd = IBNat EBNAdd
                     
fun IUnOp' (opr, rd, v) = IUnOp (opr, rd, Inner v)
fun IBinOp' (opr, rd, rs, v) = IBinOp (opr, rd, rs, Inner v)
fun IMov' (r, v) = IUnOp (IUMov, r, Inner v)
fun IBrSum' (r, v) = IUnOp (IUBrSum, r, Inner v)
fun IBrI' (r, v) = IUnOp (IUBrI, r, Inner v)
fun IBrBool' (r, v) = IUnOp (IUBrBool, r, Inner v)
fun IUnfold' (r, v) = IUnOp (IUUnfold, r, Inner v)
fun IMallocPair' (r, (v1, v2)) = IMallocPair (r, (Inner v1, Inner v2))
fun IUnpack' (name, r, v) = IUnpack (TBinder name, r, Outer v)
fun IUnpackI' (name, r, v) = IUnpackI (IBinder name, r, Outer v)
fun IInj' (r, inj, v, t) = IInj (r, inj, Inner v, Inner t)
fun IAscTime' i = IAscTime (Inner i)
                               
structure RctxUtil = MapUtilFn (Rctx)

end
