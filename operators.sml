structure Operators = struct

open Util

datatype idx_const =
         ICBool of bool
	 | ICTT
         | ICAdmit
         | ICNat of int
         | ICTime of TimeType.time

datatype idx_un_op =
         ToReal
         | Log2
         | Ceil
         | Floor
         | B2n
         | Neg
         | IUDiv of int
         | IUExp of string
               
datatype idx_bin_op =
	 AddI
	 | MultI
	 | MaxI
	 | MinI
         | IApp 
         | EqI
         | AndI
         | ExpNI
         | LtI
         | GeI
         | BoundedMinusI
         | MinusI (* only used internally for annotation propagation *)

(* binary logical connectives *)
datatype bin_conn =
	 And
	 | Or
	 | Imply
	 | Iff

(* binary predicates on indices *)
datatype bin_pred =
         EqP
         | LeP
         | LtP
         | GeP
         | GtP
         | BigO
               
(* existential quantifier might carry other information such as a unification variable to update when this existential quantifier gets instantiated *)
datatype 'a quan =
         Forall
         | Exists of 'a

type nat = int

datatype expr_const =
         ECTT
         | ECNat of nat
         | ECInt of int
         | ECString of string
         | ECBool of bool

(* projector for product type *)
datatype projector =
         ProjFst
         | ProjSnd

(* primitive unary term operators *)
datatype prim_expr_un_op =
         EUPIntNeg
         | EUPBoolNeg
         | EUPInt2Str
         | EUPStrLen
                         
datatype expr_un_op =
         EUProj of projector
         | EUPrim of prim_expr_un_op
         | EUPrint
         | EUArrayLen

fun str_expr_const c =
  case c of
      ECTT => "()"
    | ECInt n => str_int n
    | ECNat n => sprintf "#$" [str_int n]
    | ECString s => surround "\"" "\"" s
    | ECBool b => str_bool b
                                
fun str_proj opr =
  case opr of
      ProjFst => "fst"
    | ProjSnd => "snd"

fun str_prim_expr_un_op opr =
  case opr of
      EUPIntNeg => "int_neg"
    | EUPBoolNeg => "not"
    | EUPInt2Str => "int2str"
    | EUPStrLen => "str_len"
                   
fun str_expr_un_op opr = 
  case opr of
      EUProj opr => str_proj opr
    | EUPrim opr => str_prim_expr_un_op opr
    | EUPrint => "print"
    | EUArrayLen => "array_len"

(* primitive binary term operators *)
datatype prim_expr_bin_op =
         EBPIntAdd
         | EBPIntMinus
         | EBPIntMult
         | EBPIntDiv
         | EBPIntLt
         | EBPIntGt
         | EBPIntLe
         | EBPIntGe
         | EBPIntEq
         | EBPIntNEq
         | EBPBoolAnd
         | EBPBoolOr
         | EBPStrConcat

(* binary nat operators *)
datatype nat_expr_bin_op =
         EBNAdd
         | EBNBoundedMinus
         | EBNMult
         | EBNDiv
         
datatype expr_bin_op =
         EBApp
         | EBPair
         | EBNew
         | EBRead
         | EBPrim of prim_expr_bin_op
         | EBNat of nat_expr_bin_op

fun str_prim_expr_bin_op opr =
  case opr of
      EBPIntAdd => "add"
    | EBPIntMult => "mult"
    | EBPIntMinus => "minus"
    | EBPIntDiv => "div"
    | EBPIntLt => "lt"
    | EBPIntGt => "gt"
    | EBPIntLe => "le"
    | EBPIntGe => "ge"
    | EBPIntEq => "eq"
    | EBPIntNEq => "neq"
    | EBPBoolAnd => "and"
    | EBPBoolOr => "or"
    | EBPStrConcat => "str_concat"

fun str_nat_expr_bin_op opr =
  case opr of
      EBNAdd => "nat_add"
    | EBNBoundedMinus => "nat_bounded_minus"
    | EBNMult => "mult"
    | EBNDiv => "div"
                    
fun str_expr_bin_op opr =
  case opr of
      EBApp => "app"
    | EBPair => "pair"
    | EBNew => "new"
    | EBRead => "read"
    | EBPrim opr => str_prim_expr_bin_op opr
    | EBNat opr => str_nat_expr_bin_op opr

fun pretty_str_prim_expr_bin_op opr =
  case opr of
      EBPIntAdd => "+"
    | EBPIntMult => "*"
    | EBPIntMinus => "-"
    | EBPIntDiv => "/"
    | EBPIntLt => "<"
    | EBPIntGt => ">"
    | EBPIntLe => "<="
    | EBPIntGe => ">="
    | EBPIntEq => "="
    | EBPIntNEq => "<>"
    | EBPBoolAnd => "$$"
    | EBPBoolOr => "||"
    | EBPStrConcat => "^"

fun pretty_str_nat_expr_bin_op opr =
  case opr of
      EBNAdd => "#+"
    | EBNBoundedMinus => "#-"
    | EBNMult => "#*"
    | EBNDiv => "#/"
                    
fun pretty_str_expr_bin_op opr =
  case opr of
      EBApp => "$"
    | EBPair => "pair"
    | EBNew => "new"
    | EBRead => "read"
    | EBPrim opr => pretty_str_prim_expr_bin_op opr
    | EBNat opr => pretty_str_nat_expr_bin_op opr

datatype expr_tri_op =
         ETWrite
         | ETIte

datatype expr_EI =
         EEIAppI
         | EEIAscTime

datatype expr_ET =
         EETAppT
         | EETAsc

datatype expr_T =
         ETNever
         | ETBuiltin of string
             
fun str_idx_const c =
  case c of
      ICBool b => str_bool b
    | ICTT => "()"
    | ICAdmit => "admit"
    | ICNat n => str_int n
    | ICTime x => TimeType.str_time x

fun str_idx_un_op opr =
  case opr of
      ToReal => "$"
    | Log2 => "log2"
    | Ceil => "ceil"
    | Floor => "floor"
    | B2n => "b2n"
    | Neg => "not"
    | IUDiv d => sprintf "(/ $)" [str_int d]
    | IUExp s => sprintf "(^ $)" [s]

fun str_idx_bin_op opr =
  case opr of
      AddI => "+"
    | MultI => " *"
    | MaxI => "max"
    | MinI => "min"
    | IApp => "app"
    | EqI => "=="
    | AndI => "&&"
    | ExpNI => "^"
    | LtI => "<"
    | GeI => ">="
    | BoundedMinusI => "-"
    | MinusI => "MinusI"

fun str_bin_conn opr =
  case opr of
      And => "/\\"
    | Or => "\\/"
    | Imply => "->"
    | Iff => "<->"

fun str_bin_pred opr =
  case opr of
      EqP => "="
    | LeP => "<="
    | LtP => "<"
    | GeP => ">="
    | GtP => ">"
    | BigO => "<=="

fun strip_quan q =
  case q of
      Forall => Forall
    | Exists _ => Exists ()
                         
fun str_quan q =
    case q of
        Forall => "forall"
      | Exists _ => "exists"

fun str_expr_EI opr =
  case opr of
      EEIAppI => "EEIAppI"
    | EEIAscTime => "EEIAscTime"

fun str_expr_ET opr =
  case opr of
      EETAppT => "EETAppT"
    | EETAsc => "EETAsc"

fun str_expr_T opr =
  case opr of
      ETNever => "ETNever"
    | ETBuiltin name => sprintf "ETBuiltin($)" [name]
                  
end
