signature IDX_TYPE_EXPR_PARAMS = sig
  type v
  structure UVarI : UVAR_I
  structure UVarT :  UVAR_T
  type ptrn_constr_tag
end
                          
functor IdxTypeExprFn (Params : IDX_TYPE_EXPR_PARAMS) = struct
open Params
open UVarI
open UVarT
open BaseSorts
open BaseTypes
open Util
open LongId
open Operators
open Region
open Bind

type id = v * region
type name = string * region
type long_id = v long_id

structure IdxOfExpr = IdxFn (structure UVarI = UVarI
                             type base_sort = base_sort
                             type var = long_id
                             type name = name
                             type region = region
                             type 'idx exists_anno = ('idx -> unit) option
                            )
structure Idx = IdxOfExpr
open Idx

structure TypeOfExpr = TypeFn (structure Idx = Idx
                         structure UVarT = UVarT
                         type base_type = base_type
                            )
structure Type = TypeOfExpr
open Type

type cvar = var
              
open Pattern

structure ExprCore = ExprFn (
  type var = var
  type cvar = var
  type mod_id = name
  type idx = idx
  type sort = sort
  type mtype = mtype
  type ptrn_constr_tag = ptrn_constr_tag
  type ty = ty
  type kind = kind
)

open ExprCore

structure IdxUtil = IdxUtilFn (structure Idx = Idx
                               val dummy = dummy
                              )
open IdxUtil

(* some shorthands *)

val STime = Basic (Base Time, dummy)
val SNat = Basic (Base Nat, dummy)
val SBool = Basic (Base BoolSort, dummy)
val SUnit = Basic (Base UnitSort, dummy)

val Type = (0, [])

fun ETT r = EConst (ECTT, r)
fun EConstInt (n, r) = EConst (ECInt n, r)
fun EConstNat (n, r) = EConst (ECNat n, r)
fun EFst (e, r) = EUnOp (EUFst, e, r)
fun ESnd (e, r) = EUnOp (EUSnd, e, r)
fun EApp (e1, e2) = EBinOp (EBApp, e1, e2)
fun EPair (e1, e2) = EBinOp (EBPair, e1, e2)
fun EAppI (e, i) = EEI (EEIAppI, e, i)
fun EAppIs (f, args) = foldl (swap EAppI) f args
fun EAppT (e, i) = EET (EETAppT, e, i)
fun EAppTs (f, args) = foldl (swap EAppT) f args
fun EAsc (e, t) = EET (EETAsc, e, t)
fun EAscTime (e, i) = EEI (EEIAscTime, e, i)
fun ENever (t, r) = ET (ETNever, t, r)
fun EBuiltin (t, r) = ET (ETBuiltin, t, r)
  
(* notations *)
         
infixr 0 $

infix 9 %@
infix 8 %^
infix 7 %*
infix 6 %+ 
infix 4 %<=
infix 4 %>=
infix 4 %=
infixr 3 /\
infixr 2 \/
infixr 1 -->
infix 1 <->
        
(* useful functions *)

open Bind
       
fun collect_EAppI e =
  case e of
      EEI (opr, e, i) =>
      (case opr of
           EEIAppI =>
             let 
               val (e, is) = collect_EAppI e
             in
               (e, is @ [i])
             end
         | _ => (e, [])
      )
    | _ => (e, [])

fun collect_EAppT e =
  case e of
      EET (opr, e, i) =>
      (case opr of
           EETAppT =>
           let 
             val (e, is) = collect_EAppT e
           in
             (e, is @ [i])
           end
         | _ => (e, [])
      )
    | _ => (e, [])

fun collect_BSArrow b =
  case b of
      Base _ => ([], b)
    | BSArrow (a, b) =>
      let
        val (args, ret) = collect_BSArrow b
      in
        (a :: args, ret)
      end
    | UVarBS u => ([], b)

fun combine_BSArrow (args, b) = foldr BSArrow b args
                    
fun is_IApp_UVarI i =
  let
    val (f, args) = collect_IApp i
  in
    case f of
        UVarI (x, r) => SOME ((x, r), args)
      | _ => NONE
  end
    
fun collect_SApp s =
  case s of
      SApp (s, i) =>
      let 
        val (s, is) = collect_SApp s
      in
        (s, is @ [i])
      end
    | _ => (s, [])
             
fun is_SApp_UVarS s =
  let
    val (f, args) = collect_SApp s
  in
    case f of
        UVarS (x, r) => SOME ((x, r), args)
      | _ => NONE
  end
    
fun collect_MtAppI t =
  case t of
      MtAppI (t, i) =>
      let 
        val (f, args) = collect_MtAppI t
      in
        (f, args @ [i])
      end
    | _ => (t, [])
             
fun collect_MtApp t =
  case t of
      MtApp (t1, t2) =>
      let 
        val (f, args) = collect_MtApp t1
      in
        (f, args @ [t2])
      end
    | _ => (t, [])
             
fun is_MtApp_UVar t =
  let
    val (t, t_args) = collect_MtApp t
    val (t, i_args) = collect_MtAppI t
  in
    case t of
        UVar (x, r) => SOME ((x, r), i_args, t_args)
      | _ => NONE
  end
    
fun is_AppV t =
  let
    val (t, i_args) = collect_MtAppI t
    val (t, t_args) = collect_MtApp t
  in
    case t of
        MtVar x => SOME (x, t_args, i_args)
      | _ => NONE
  end
    
fun IApps f args = foldl (fn (arg, f) => BinOpI (IApp, f, arg)) f args
fun SApps f args = foldl (fn (arg, f) => SApp (f, arg)) f args
fun MtAppIs f args = foldl (fn (arg, f) => MtAppI (f, arg)) f args
fun MtApps f args = foldl (fn (arg, f) => MtApp (f, arg)) f args
fun SAbsMany (ctx, s, r) = foldl (fn ((name, s_arg), s) => SAbs (s_arg, Bind ((name, r), s), r)) s ctx
fun IAbsMany (ctx, i, r) = foldl (fn ((name, b), i) => IAbs (b, Bind ((name, r), i), r)) i ctx
fun MtAbsMany (ctx, t, r) = foldl (fn ((name, k), t) => MtAbs (k, Bind ((name, r), t), r)) t ctx
fun MtAbsIMany (ctx, t, r) = foldl (fn ((name, s), t) => MtAbsI (s, Bind ((name, r), t), r)) t ctx
                                 
fun AppVar (x, is) = MtAppIs (MtVar x) is
fun AppV (x, ts, is, r) = MtAppIs (MtApps (MtVar x) ts) is

val VarT = MtVar
fun constr_type (VarT : int LongId.long_id -> mtype) shiftx_long_id ((family, tbinds) : mtype constr_info) = 
  let
    val (tname_kinds, ibinds) = unfold_binds tbinds
    val tnames = map fst tname_kinds
    val (ns, (t, is)) = unfold_binds ibinds
    val ts = map (fn x => VarT (ID (x, dummy))) $ rev $ range $ length tnames
    val t2 = AppV (shiftx_long_id 0 (length tnames) family, ts, is, dummy)
    val t = Arrow (t, T0 dummy, t2)
    val t = foldr (fn ((name, s), t) => UniI (s, Bind (name, t), dummy)) t ns
    val t = Mono t
    val t = foldr (fn (name, t) => Uni (Bind (name, t), dummy)) t tnames
  in
    t
  end

fun get_constr_inames (core : mtype constr_core) =
  let
    val (name_sorts, _) = unfold_binds core
  in
    map fst $ map fst name_sorts
  end
                                 
(* region calculations *)

fun get_region_long_id id =
  case id of
      ID x => snd x
    | QID (m, x) => combine_region (snd m) (snd x)
                                         
fun set_region_long_id id r =
  case id of
      ID (x, _) => ID (x, r)
    | QID ((m, _), (x, _)) => QID ((m, r), (x, r))

structure IdxGetRegion = IdxGetRegionFn (structure Idx = Idx
                                         val get_region_var = get_region_long_id
                                         val set_region_var = set_region_long_id)
open IdxGetRegion
       
structure TypeGetRegion = TypeGetRegionFn (structure Type = Type
                                           val get_region_var = get_region_long_id
                                           val get_region_i = get_region_i)
open TypeGetRegion
       
structure ExprGetRegion = ExprGetRegionFn (structure Expr = ExprCore
                                           val get_region_var = get_region_long_id
                                           val get_region_cvar = get_region_long_id
                                           val get_region_i = get_region_i
                                           val get_region_mt = get_region_mt
                                          )
open ExprGetRegion

(* mlton needs these lines *)                                         
structure Idx = IdxOfExpr
open Idx
structure Type = TypeOfExpr
open Type
       
fun is_value (e : expr) : bool =
  case e of
      EVar _ => true
    | EConst (c, _) =>
      (case c of
           ECTT => true
         | ECNat _ => true
         | ECInt _ => true
      )
    | EUnOp (opr, e, _) =>
      (case opr of
           EUFst => false
         | EUSnd => false
      )
    | EBinOp (opr, e1, e2) =>
      (case opr of
           EBApp => false
         | EBPair => is_value e1 andalso is_value e2
         | EBNew => false
         | EBRead => false
         | EBAdd => false
      )
    | ETriOp _ => false
    | EEI (opr, e, i) =>
      (case opr of
           EEIAppI => false
         | EEIAscTime => false
      )
    | EET (opr, e, t) =>
      (case opr of
           EETAppT => false
         | EETAsc => false
      )
    | ET (opr, t, _) =>
      (case opr of
           ETNever => true
         | ETBuiltin => true
      )
    | EAbs _ => true
    | EAbsI _ => true
    | ELet _ => false
    | EAppConstr (_, _, _, e, _) => is_value e
    | ECase _ => false

end

(* Test that the result of [ExprFun] matches some signatures. We don't use a signature ascription because signature ascription (transparent or opaque) hides components that are not in the signature. SML should have a "signature check" kind of ascription. *)
functor TestIdxTypeExprFnSignatures (Params : IDX_TYPE_EXPR_PARAMS) = struct
structure M : IDX = IdxTypeExprFn (Params)
structure M2 : TYPE = IdxTypeExprFn (Params)
structure M3 : EXPR = IdxTypeExprFn (Params)
structure M4 : IDX_TYPE_EXPR = IdxTypeExprFn (Params)
end
