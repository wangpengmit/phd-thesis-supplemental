structure MicroTiMLUtil = struct

open Util
open Binders
open MicroTiML

infixr 0 $

fun KArrows bs k = foldr KArrow k bs
fun KArrowTs ks k = foldr KArrowT k ks
fun KArrowTypes n k = KArrowTs (repeat n $ KType ()) k
                          
fun TForall (i, bind) = TQuan (Forall (), i, bind)
fun TAbsI_Many (ctx, t) = foldr (TAbsI o BindAnno) t ctx
fun TAbsT_Many (ctx, t) = foldr (TAbsT o BindAnno) t ctx
val TUni = TForall
fun MakeTUni (name, k, i, t) = TUni (i, TBindAnno ((name, k), t))
fun TUniKind (name, i, t) = MakeTUni (name, KType (), i, t)
fun TUniKind_Many (names, t) = foldr (fn ((name, i), t) => TUniKind (name, i, t)) t names

(* val TCString = TCTiML BaseTypes.String *)
val TCInt = TCTiML (BaseTypes.BTInt ())
val TCBool = TCTiML (BaseTypes.BTBool ())
val TCByte = TCTiML (BaseTypes.BTByte ())
val TUnit = TConst (TCUnit ())
val TEmpty = TConst (TCEmpty ())
(* val TString = TConst TCString *)
val TInt = TConst TCInt
val TBool = TConst TCBool
val TByte = TConst TCByte
fun TSum (t1, t2) = TBinOp (TBSum (), t1, t2)
(* fun TProd (t1, t2) = TBinOp (TBProd (), t1, t2) *)
fun TProd (t1, t2) = TTuple [t1, t2]          
fun TAppIs (t, is) = foldl (swap TAppI) t is
fun TAppTs (t, ts) = foldl (swap TAppT) t ts
fun TMemTuplePtr (ts, i) = TTuplePtr (ts, i, false)
fun TStorageTuplePtr (ts, i) = TTuplePtr (ts, i, true)
         
fun EPair (e1, e2) = ETuple [e1, e2]
fun EProj (proj, e) = EUnOp (EUTiML $ EUProj proj, e)
(* fun EFst e = EProj (ProjFst (), e) *)
(* fun ESnd e = EProj (ProjSnd (), e) *)
fun EFst e = EProj (0, e)
fun ESnd e = EProj (1, e)
fun EInj (inj, t, e) = EUnOp (EUInj (inj, t), e)
fun EInl (t, e) = EInj (InjInl (), t, e)
fun EInr (t, e) = EInj (InjInr (), t, e)
fun EFold (t, e) = EUnOp (EUFold t, e)
fun EUnfold e = EUnOp (EUUnfold (), e)
fun EApp (e1, e2) = EBinOp (EBApp (), e1, e2)

fun EBinOpPrim (opr, e1, e2) = EBinOp (EBPrim opr, e1, e2)
fun EIntAdd (e1, e2) = EBinOpPrim (EBPIntAdd (), e1, e2)
val EBNatAdd = EBNat (EBNAdd ())
fun ENatAdd (e1, e2) = EBinOp (EBNatAdd, e1, e2)
fun ENew (w, e1, e2) = EBinOp (EBNew w, e1, e2)
fun ERead (w, e1, e2) = EBinOp (EBRead w, e1, e2)
fun EWrite (w, e1, e2, e3) = ETriOp (ETWrite w, e1, e2, e3)
                                      
fun MakeEAbs (i, name, t, e) = EAbs (i, EBindAnno ((name, t), e), NONE)
fun MakeEAbsWithAnno (i, name, t, e, spec) = EAbs (i, EBindAnno ((name, t), e), spec)
fun MakeEAbsI (name, s, e) = EAbsI $ IBindAnno ((name, s), e)
fun MakeEUnpack (e1, tname, ename, e2) = EUnpack (e1, TBind (tname, EBind (ename, e2)))
fun MakeEAbsT (name, k, e) = EAbsT $ TBindAnno ((name, k), e)
fun MakeERec (name, t, e) = ERec $ EBindAnno ((name, t), e)
fun MakeEUnpackI (e1, iname, ename, e2) = EUnpackI (e1, IBind (iname, EBind (ename, e2)))
fun MakeELet (e1, name, e2) = ELet (e1, EBind (name, e2))
fun MakeELetIdx (i, name, e) = ELetIdx (i, IBind (name, e))
fun MakeELetType (t, name, e) = ELetType (t, TBind (name, e))
fun MakeELetConstr (e1, name, e2) = ELetConstr (e1, CBind (name, e2))
fun MakeEAbsConstr (tnames, inames, ename, e) = EAbsConstr $ Bind ((map TBinder tnames, map IBinder inames, EBinder ename), e)
fun MakeECase (e, (name1, e1), (name2, e2)) = ECase (e, EBind (name1, e1), EBind (name2, e2))
fun MakeTQuanI (q, s, name, i, t) = TQuanI (q, IBindAnno ((name, s), (i, t)))
fun MakeTQuan (q, k, name, i, t) = TQuan (q, i, TBindAnno ((name, k), t))
fun MakeTForallI (s, name, i, t) = MakeTQuanI (Forall (), s, name, i, t)
fun MakeTForall (s, name, i, t) = MakeTQuan (Forall (), s, name, i, t)
fun EAbsTKind (name, e) = MakeEAbsT (name, KType (), e) 
fun EAbsTKind_Many (names, e) = foldr EAbsTKind e names
fun MakeEMatchTuple (e1, names, e2) = EMatchTuple (e1, Bind (map Binder names, e2))

(* fun choose_update (b1, b2) proj = *)
(*   case proj of *)
(*       ProjFst () => (true, b2) *)
(*     | ProjSnd () => (b1, true) *)
                   
fun choose_inj (t1, t2) inj =
  case inj of
      InjInl () => t1
    | InjInr () => t2
                                 
fun choose_pair_inj (t, t_other) inj =
  case inj of
      InjInl () => (t, t_other)
    | InjInr () => (t_other, t)
                  
fun collect_EAscType_rev e =
  let
    val self = collect_EAscType_rev
  in
    case e of
        EAscType (e, t) =>
        let
          val (e, args) = self e
        in
          (e, t :: args)
        end
      | _ => (e, [])
  end
fun collect_EAscType e = mapSnd rev $ collect_EAscType_rev e
                                
fun collect_EAscTime_rev e =
  let
    val self = collect_EAscTime_rev
  in
    case e of
        EAscTime (e, i) =>
        let
          val (e, args) = self e
        in
          (e, i :: args)
        end
      | _ => (e, [])
  end
fun collect_EAscTime e = mapSnd rev $ collect_EAscTime_rev e
                                
fun EAscTypes (e, ts) = foldl (swap EAscType) e ts
fun EAscTimes (e, is) = foldl (swap EAscTime) e is

val unEAbsI = unBindAnnoName
val unEAbsT = unBindAnnoName
                
fun collect_EAbsI e =
  case e of
      EAbsI data =>
      let
        val (s, (name, e)) = unEAbsI data
        val (binds, e) = collect_EAbsI e
      in
        ((name, s) :: binds, e)
      end
    | _ => ([], e)

fun EAbsIs (binds, b) = foldr (EAbsI o IBindAnno) b binds
                               
fun collect_EAbsIT e =
  case e of
      EAbsI data =>
      let
        val (s, (name, e)) = unEAbsI data
        val (binds, e) = collect_EAbsIT e
      in
        (inl (name, s) :: binds, e)
      end
    | EAbsT data =>
      let
        val (k, (name, e)) = unEAbsT data
        val (binds, e) = collect_EAbsIT e
      in
        (inr (name, k) :: binds, e)
      end
    | _ => ([], e)

fun collect_TAbsIT b =
  case b of
      TAbsI data =>
      let
        val (s, (name, b)) = unBindAnnoName data
        val (binds, b) = collect_TAbsIT b
      in
        (inl (name, s) :: binds, b)
      end
    | TAbsT data =>
      let
        val (k, (name, b)) = unBindAnnoName data
        val (binds, b) = collect_TAbsIT b
      in
        (inr (name, k) :: binds, b)
      end
    | _ => ([], b)

fun eq_t a = MicroTiMLVisitor2.eq_t_fn (curry Equal.eq_var, Equal.eq_bs, Equal.eq_i, Equal.eq_s) a
                     
fun collect_ELet e =
  case e of
      ELet (e1, bind) =>
      let
        val (name, e) = unBindSimpName bind
        val (decls, e) = collect_ELet e
      in
        ((name, e1) :: decls, e)
      end
    | _ => ([], e)
fun ELets (decls, e) = foldr (fn ((name, e1), e) => ELet (e1, EBind (name, e))) e decls

fun collect_EAppI e =
  case e of
      EAppI (e, i) =>
      let 
        val (e, is) = collect_EAppI e
      in
        (e, is @ [i])
      end
    | _ => (e, [])
fun EAppIs (f, args) = foldl (swap EAppI) f args
                             
fun assert_fail msg = Impossible $ "Assert failed: " ^ msg
                             
fun assert_TiBool t =
  case t of
      TiBool a => a
    | _ => raise assert_fail $ "assert_TiBool"

infix 0 %:
infix 0 |>
infix 0 |#
infix 0 %~
infix 0 |>#
        
fun a %: b = EAscType (a, b)
fun a |> b = EAscTime (a, b)
fun a |# b = EAscSpace (a, b)
fun a %~ b = EAscState (a, b)
fun EAscTimeSpace (e, (i, j)) = e |> i |# j
fun a |># b = EAscTimeSpace (a, b)

fun EAnno (e, a) = EUnOp (EUTiML (EUAnno a), e)
fun EAnnoLiveVars (e, n) = EAnno (e, EALiveVars n)
fun EAnnoBodyOfRecur e = EAnno (e, EABodyOfRecur ())
fun EAnnoFreeEVars (e, n) = EAnno (e, EAFreeEVars n)
                                 
fun EAbsIT (bind, e) =
    case bind of
        inl bind => EAbsI $ IBindAnno (bind, e)
      | inr bind => EAbsT $ TBindAnno (bind, e)
fun EAbsITs (binds, e) = foldr EAbsIT e binds

(* fun ETupleProj (e, n) = EUnOp (EUTupleProj n, e) *)
  
fun is_tail_call e =
  case e of
      EBinOp (EBApp (), _, _) => true
    | EAppT _ => true
    | EAppI _ => true
    | ECase _ => true 
    | EIfi _ => true 
    | ETriOp (ETIte (), _, _, _) => true
    | EUnOp (EUTiML (EUAnno _), e) => is_tail_call e
    | EAscTime (e, _) => is_tail_call e
    | EAscSpace (e, _) => is_tail_call e
    | EAscType (e, _) => is_tail_call e
    | EAscState (e, _) => is_tail_call e
    | ELet (_, bind) => is_tail_call $ snd $ unBindSimp bind
    | EUnpack (_, bind) => is_tail_call $ snd $ unBindSimp $ snd $ unBindSimp bind
    | EUnpackI (_, bind) => is_tail_call $ snd $ unBindSimp $ snd $ unBindSimp bind
    | _ => false
                       
fun map_kind f k =
    case k of
        KType () => KType ()
      | KArrow (b, k) => KArrow (f b, map_kind f k)
      | KArrowT (k1, k2) => KArrowT (map_kind f k1, map_kind f k2)

fun collect_all_anno_rev e =
  let
    val self = collect_all_anno_rev
  in
    case e of
        EAscType (e, t) =>
        let
          val (e, args) = self e
        in
          (e, AnnoType t :: args)
        end
      | EAscTime (e, i) =>
        let
          val (e, args) = self e
        in
          (e, AnnoTime i :: args)
        end
      | EAscSpace (e, i) =>
        let
          val (e, args) = self e
        in
          (e, AnnoSpace i :: args)
        end
      | EAscState (e, i) =>
        let
          val (e, args) = self e
        in
          (e, AnnoState i :: args)
        end
      | EUnOp (EUTiML (EUAnno anno), e) =>
        let
          val (e, args) = self e
        in
          (e, AnnoEA anno :: args)
        end
      | _ => (e, [])
  end
fun collect_all_anno e = mapSnd rev $ collect_all_anno_rev e

fun collect_TAppIT_rev t =
  let
    val self = collect_TAppIT_rev
  in
    case t of
        TAppI (t, i) =>
        let
          val (t, args) = self t
        in
          (t, inl i :: args)
        end
      | TAppT (t, t') =>
        let
          val (t, args) = self t
        in
          (t, inr t' :: args)
        end
      | _ => (t, [])
  end
fun collect_TAppIT t = mapSnd rev $ collect_TAppIT_rev t

fun TAppITs t args =
  foldl (fn (arg, t) => case arg of inl i => TAppI (t, i) | inr t' => TAppT (t, t')) t args

fun collect_TForallIT b =
  case b of
      TQuanI (Forall (), bind) =>
      let
        val (s, (name, (_, b))) = unBindAnnoName bind
        val (binds, b) = collect_TForallIT b
      in
        (inl (name, s) :: binds, b)
      end
    | TQuan (Forall (), _, bind) =>
      let
        val (k, (name, b)) = unBindAnnoName bind
        val (binds, b) = collect_TForallIT b
      in
        (inr (name, k) :: binds, b)
      end
    | _ => ([], b)

fun collect_TExistsIT b =
  case b of
      TQuanI (Exists _, bind) =>
      let
        val (s, (name, (_, b))) = unBindAnnoName bind
        val (binds, b) = collect_TExistsIT b
      in
        (inl (name, s) :: binds, b)
      end
    | TQuan (Exists _, _, bind) =>
      let
        val (k, (name, b)) = unBindAnnoName bind
        val (binds, b) = collect_TExistsIT b
      in
        (inr (name, k) :: binds, b)
      end
    | _ => ([], b)

end
                                 
