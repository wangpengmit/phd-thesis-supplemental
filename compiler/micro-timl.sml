structure MicroTiML = struct

open Region
type name = string * region
open Namespaces
                       
open Binders
open Operators

(* kind *)
datatype 'bsort kind =
         KType of unit
         | KArrow of 'bsort * 'bsort kind
         | KArrowT of 'bsort kind * 'bsort kind

(* type constants *)
datatype ty_const =
         TCUnit of unit
         | TCEmpty of unit
         | TCTiML of BaseTypes.base_type

(* binary type constructors *)
datatype ty_bin_op =
         TBSum of unit
         (* | TBProd of unit *)

structure Rctx = IntBinaryMap
                   
(* type *)
datatype ('var, 'bsort, 'idx, 'sort) ty =
         TVar of 'var * 'bsort kind list
         | TConst of ty_const
         | TBinOp of ty_bin_op * ('var, 'bsort, 'idx, 'sort) ty * ('var, 'bsort, 'idx, 'sort) ty
         | TArrow of ('idx * ('var, 'bsort, 'idx, 'sort) ty) * ('idx * 'idx) * ('idx * ('var, 'bsort, 'idx, 'sort) ty)
         | TAbsI of ('bsort, ('var, 'bsort, 'idx, 'sort) ty) ibind_anno
         | TAppI of ('var, 'bsort, 'idx, 'sort) ty * 'idx
         | TQuan of unit Operators.quan * ('idx * 'idx) * ('bsort kind, ('var, 'bsort, 'idx, 'sort) ty) tbind_anno
         | TQuanI of unit Operators.quan * ('sort, ('idx * 'idx) * ('var, 'bsort, 'idx, 'sort) ty) ibind_anno
         | TRec of ('bsort kind, ('var, 'bsort, 'idx, 'sort) ty) tbind_anno
         | TNat of 'idx
         | TArray of int * ('var, 'bsort, 'idx, 'sort) ty * 'idx
         | TAbsT of ('bsort kind, ('var, 'bsort, 'idx, 'sort) ty) tbind_anno
         | TAppT of ('var, 'bsort, 'idx, 'sort) ty * ('var, 'bsort, 'idx, 'sort) ty
         | TiBool of 'idx
         | TTuple of ('var, 'bsort, 'idx, 'sort) ty list
         | TRecord of ('var, 'bsort, 'idx, 'sort) ty SMap.map
         | TState of string
         | TMap of ('var, 'bsort, 'idx, 'sort) ty
         | TVector of ('var, 'bsort, 'idx, 'sort) ty
         | TSCell of ('var, 'bsort, 'idx, 'sort) ty
         | TNatCell of unit
         | TPtr of ('var, 'bsort, 'idx, 'sort) ty
         (* used by compiler/pair-alloc *)
         (* | TProdEx of (('var, 'bsort, 'idx, 'sort) ty * bool) * (('var, 'bsort, 'idx, 'sort) ty * bool) *)
         (* used by compiler/code-gen *)
         (* | TArrowTAL of ('var, 'bsort, 'idx, 'sort) ty Rctx.map * 'idx *)
         | TArrowEVM of 'idx(*pre-state*) * ('var, 'bsort, 'idx, 'sort) ty Rctx.map (*register typing*) * ('var, 'bsort, 'idx, 'sort) ty list (*stack typing*) * ('idx * 'idx)
         | TPreTuple of ('var, 'bsort, 'idx, 'sort) ty list * int(*offset*) * int(*lowest inited pos*)
         | TTuplePtr of ('var, 'bsort, 'idx, 'sort) ty list * int(*offset*) * bool(*is storage?*)
         | TPreArray of int(*width*) * ('var, 'bsort, 'idx, 'sort) ty * 'idx(*len*) * 'idx(*lowest inited/uninited pos*) * (bool(*is length inited?*) * bool(*init direction; false: downward; true: upward *))
         | TArrayPtr of int(*width*) * ('var, 'bsort, 'idx, 'sort) ty * 'idx(*len*) * 'idx(*offset*)
         | TVectorPtr of string * 'idx(*offset*)

type loc = int
             
(* injector for sum type *)
datatype injector =
         InjInl of unit
         | InjInr of unit

(* unary term operators *)
datatype 'ty expr_un_op =
         EUInj of injector * 'ty
         | EUFold of 'ty
         | EUUnfold of unit
         | EUTiML of Operators.expr_un_op
         (* | EUTupleProj of int *)
         (* | EUExfalso of 'ty *)

(* term *)
datatype ('var, 'idx, 'sort, 'kind, 'ty) expr =
         EVar of 'var
         | EConst of Operators.expr_const
         | EState of string
         | EUnOp of 'ty expr_un_op * ('var, 'idx, 'sort, 'kind, 'ty) expr
         | EBinOp of expr_bin_op * ('var, 'idx, 'sort, 'kind, 'ty) expr * ('var, 'idx, 'sort, 'kind, 'ty) expr
         | ETriOp of expr_tri_op * ('var, 'idx, 'sort, 'kind, 'ty) expr * ('var, 'idx, 'sort, 'kind, 'ty) expr * ('var, 'idx, 'sort, 'kind, 'ty) expr
         | ECase of ('var, 'idx, 'sort, 'kind, 'ty) expr * ('var, 'idx, 'sort, 'kind, 'ty) expr ebind * ('var, 'idx, 'sort, 'kind, 'ty) expr ebind
         | EAbs of 'idx(*pre-condition*) * ('ty, ('var, 'idx, 'sort, 'kind, 'ty) expr) ebind_anno * ('idx * 'idx) option
         | ERec of ('ty, ('var, 'idx, 'sort, 'kind, 'ty) expr) ebind_anno
         | EAbsT of ('kind, ('var, 'idx, 'sort, 'kind, 'ty) expr) tbind_anno
         | EAppT of ('var, 'idx, 'sort, 'kind, 'ty) expr * 'ty
         | EAbsI of ('sort, ('var, 'idx, 'sort, 'kind, 'ty) expr) ibind_anno
         | EAppI of ('var, 'idx, 'sort, 'kind, 'ty) expr * 'idx
         | EPack of 'ty * 'ty * ('var, 'idx, 'sort, 'kind, 'ty) expr
         | EUnpack of ('var, 'idx, 'sort, 'kind, 'ty) expr * ('var, 'idx, 'sort, 'kind, 'ty) expr ebind tbind
         | EPackI of 'ty * 'idx * ('var, 'idx, 'sort, 'kind, 'ty) expr
         | EUnpackI of ('var, 'idx, 'sort, 'kind, 'ty) expr * ('var, 'idx, 'sort, 'kind, 'ty) expr ebind ibind
         | EAscTime of ('var, 'idx, 'sort, 'kind, 'ty) expr * 'idx (* time ascription *)
         | EAscSpace of ('var, 'idx, 'sort, 'kind, 'ty) expr * 'idx (* space annotation *)
         | EAscState of ('var, 'idx, 'sort, 'kind, 'ty) expr * 'idx (* post-state annotation *)
         | EAscType of ('var, 'idx, 'sort, 'kind, 'ty) expr * 'ty (* type ascription *)
         | ENever of 'ty
         | EBuiltin of string * 'ty
         | ELet of ('var, 'idx, 'sort, 'kind, 'ty) expr * ('var, 'idx, 'sort, 'kind, 'ty) expr ebind
         | ENewArrayValues of int * 'ty * ('var, 'idx, 'sort, 'kind, 'ty) expr list
         | ETuple of ('var, 'idx, 'sort, 'kind, 'ty) expr list
         | ERecord of ('var, 'idx, 'sort, 'kind, 'ty) expr SMap.map
         (* extensions from MicroTiML *)
         | ELetIdx of 'idx * ('var, 'idx, 'sort, 'kind, 'ty) expr ibind
         | ELetType of 'ty * ('var, 'idx, 'sort, 'kind, 'ty) expr tbind
         | ELetConstr of ('var, 'idx, 'sort, 'kind, 'ty) expr * ('var, 'idx, 'sort, 'kind, 'ty) expr cbind
         | EAbsConstr of (tbinder list * ibinder list * ebinder, ('var, 'idx, 'sort, 'kind, 'ty) expr) bind
         | EAppConstr of ('var, 'idx, 'sort, 'kind, 'ty) expr * 'ty list * 'idx list * ('var, 'idx, 'sort, 'kind, 'ty) expr
         | EVarConstr of 'var (* todo: should be 'cvar *)
         | EPackIs of 'ty * 'idx list * ('var, 'idx, 'sort, 'kind, 'ty) expr
         | EMatchSum of ('var, 'idx, 'sort, 'kind, 'ty) expr * ('var, 'idx, 'sort, 'kind, 'ty) expr ebind list
         (* | EMatchPair of ('var, 'idx, 'sort, 'kind, 'ty) expr * ('var, 'idx, 'sort, 'kind, 'ty) expr ebind ebind *)
         | EMatchTuple of ('var, 'idx, 'sort, 'kind, 'ty) expr * (ebinder list, ('var, 'idx, 'sort, 'kind, 'ty) expr) bind
         | EMatchUnfold of ('var, 'idx, 'sort, 'kind, 'ty) expr * ('var, 'idx, 'sort, 'kind, 'ty) expr ebind
         | EIfi of ('var, 'idx, 'sort, 'kind, 'ty) expr * ('var, 'idx, 'sort, 'kind, 'ty) expr ebind * ('var, 'idx, 'sort, 'kind, 'ty) expr ebind
         (* introduced by compiler/CPS *)
         | EHalt of bool(*successful?*) * ('var, 'idx, 'sort, 'kind, 'ty) expr * 'ty
         | EEnv of env_info
         | EDispatch of (string * ('var, 'idx, 'sort, 'kind, 'ty) expr * 'ty * 'ty) list
         (* | EDebugLog of ('var, 'idx, 'sort, 'kind, 'ty) expr *)
         (* introduced by compiler/pair-alloc *)
         (* | EMallocPair of ('var, 'idx, 'sort, 'kind, 'ty) expr * ('var, 'idx, 'sort, 'kind, 'ty) expr (* These two expressions are only here to determine the types. They have no runtime behavior and should always be values. They are used to avoid type annotations here which could be large. *) *)
         (* | EPairAssign of ('var, 'idx, 'sort, 'kind, 'ty) expr * projector * ('var, 'idx, 'sort, 'kind, 'ty) expr *)
         (* | EProjProtected of projector * ('var, 'idx, 'sort, 'kind, 'ty) expr *)

(*********** utilities ***************)    

fun collect_TBinOp_left opr t =
  case t of
      TBinOp (opr', t1, t2) =>
      if opr' = opr then
        collect_TBinOp_left opr t1 @ [t2]
      else [t]
    | _ => [t]
             
(* fun collect_TProd_left a = collect_TBinOp_left (TBProd ()) a *)
                                            
infixr 0 $
         
fun collect_EAscTypeTime_rev e =
  let
    val self = collect_EAscTypeTime_rev
  in
    case e of
        EAscType (e, t) =>
        let
          val (e, args) = self e
        in
          (e, inl t :: args)
        end
      | EAscTime (e, i) =>
        let
          val (e, args) = self e
        in
          (e, inr i :: args)
        end
      | _ => (e, [])
  end
fun collect_EAscTypeTime e = mapSnd rev $ collect_EAscTypeTime_rev e

(* ignores EAscType/Time except those for the core *)
fun collect_EAppIT_rev e =
  let
    val self = collect_EAppIT_rev
  in
    case fst $ collect_EAscTypeTime e of
        EAppI (e, i) =>
        let
          val (e, args) = self e
        in
          (e, inl i :: args)
        end
      | EAppT (e, t) =>
        let
          val (e, args) = self e
        in
          (e, inr t :: args)
        end
      | _ => (e, [])
  end
fun collect_EAppIT e = mapSnd rev $ collect_EAppIT_rev e

(* Treats EAppI/T (v, _) as a value. This is OK because EAbsI/T is always around a value, therefore deferring the reduction of EAppI/T (EAbsI/T _, _) won't change any side effect. Another angle to look at it is that if we use SML's erasure semantics where all types are erased before execution, then the reduction of EAppI/T (EAbsI/T _, _) is a no-op.
*)
fun is_value e =
  case e of
      EConst _ => true
    | EDispatch _ => true (* pretend to be an EConst *)
    (* | EDebugLog _ => true (* pretend to be an EConst *) *)
    | EState _ => true
    | EEnv _ => true
    (* | EBinOp (EBPair (), e1, e2) => is_value e1 andalso is_value e2 *)
    | ERecord fields => SMapU.all is_value fields
    | ETuple es => List.all is_value es
    | EUnOp (EUInj _, e) => is_value e
    | EAbs _ =>  true
    | EAbsT _ => true
    | EAbsI _ => true
    | EPack (_, _, e) => is_value e
    | EPackI (_, _, e) => is_value e
    | EPackIs (_, _, e) => is_value e
    | EUnOp (EUFold _, e) => is_value e
    | EAscType (e, _) => is_value e
    | EAscTime (e, _) => is_value e
    | EAscSpace (e, _) => is_value e
    | EAscState (e, _) => is_value e
    (* | ELoc _ => true *)
    | EAppT (e, _) => is_value e
    | EAppI (e, _) => is_value e
    | ERec data =>
      let
        val (_, (_, e)) = unBindAnnoName data
      in
        is_value e
      end
    | EVar _ => true (* variables denote values *)
    | ENever _ => true
    | EBuiltin _ => true
    | EAbsConstr _ => true
    | EVarConstr _ => true
    | EBinOp (EBApp (), _, _) => false
    | EBinOp (EBNew _, _, _) => false
    | EBinOp (EBRead _, _, _) => false
    | EBinOp (EBPrim _, _, _) => false
    | EBinOp (EBiBool _, _, _) => false
    | EBinOp (EBNat _, _, _) => false
    | EBinOp (EBNatCmp _, _, _) => false
    | EBinOp (EBIntNatExp _, _, _) => false
    | EBinOp (EBVectorGet (), _, _) => false
    | EBinOp (EBVectorPushBack (), _, _) => false
    | EBinOp (EBMapPtr (), _, _) => false
    | EBinOp (EBStorageSet (), _, _) => false
    | EBinOp (EBNatCellSet (), _, _) => false
    | EUnOp (EUUnfold (), _) => false
    | EUnOp (EUTiML opr, e) =>
      (case opr of
           EUProj _ => false
         | EUPtrProj _ => false
         | EUArrayLen () => false
         | EUPrim _ => false
         | EUiBoolNeg () => false
         | EUNat2Int () => false
         | EUInt2Nat () => false
         | EUPrintc () => false
         (* | EUPrint () => false *)
         | EUDebugLog _ => true (* pretend to be an EConst *)
         | EUStorageGet () => false
         | EUNatCellGet () => false
         | EUVectorClear () => false
         | EUVectorLen () => false
         | EUAnno _ => is_value e
         | EUField _ => false
      )
    (* | EUnOp (EUTupleProj _, _) => false *)
    | ETriOp (ETWrite _, _, _, _) => false
    | ETriOp (ETIte (), _, _, _) => false
    | ETriOp (ETVectorSet (), _, _, _) => false
    | ECase _ => false
    | EUnpack _ => false
    | EUnpackI _ => false
    | ELet _ => false
    | ENewArrayValues _ => false
    | ELetIdx _ => false
    | ELetType _ => false
    | ELetConstr _ => false
    | EAppConstr _ => false
    | EMatchSum _ => false
    (* | EMatchPair _ => false *)
    | EMatchTuple _ => false
    | EMatchUnfold _ => false
    | EIfi _ => false
    | EHalt _ => false
    (* | EMallocPair _ => false *)
    (* | EPairAssign _ => false *)
    (* | EProjProtected _ => false *)
    (* | _ => *)
    (*   case fst $ collect_EAscTypeTime $ fst $ collect_EAppIT e of *)
    (*       ERec data => *)
    (*       let *)
    (*         val (_, (_, e)) = unBindAnnoName data *)
    (*       in *)
    (*         is_value e *)
    (*       end *)
    (*     | EVar _ => true (* todo: is this right? *) *)
    (*     | _ => false *)

end
