(* unification *)

functor UnifyFn (exception UnifyError of Region.region * string list) = struct
open CollectVar
open ParaSubst
open Expr
open Util
open UVar
open Subst
open Normalize
open TypecheckUtil
       
infixr 0 $
infix 0 !!

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
        
infix  9 @!!
fun m @!! k = StMapU.must_find m k
                               
fun unify_error cls r (s, s') =             
  UnifyError (r, [sprintf "Can't unify $ " [cls]] @ indent [s] @ ["and"] @ indent [s'])

(* assumes arguments are already checked for well-formedness *)
fun unify_bs r (bs, bs') =
  let
    (* val () = println $ sprintf "unifying bsorts $ and $" [str_bs bs, str_bs bs'] *)
  in
    case (update_bs bs, update_bs bs') of
        (BSUVar x, _) =>
        refine x bs'
      | (_, BSUVar _) =>
        unify_bs r (bs', bs)
      | (BSArrow (a, b), BSArrow (a', b')) => (unify_bs r (a, a'); unify_bs r (b, b'))
      | (BSBase b, BSBase b') =>
        if b = b' then
	  ()
        else
	  raise UnifyError (r, [sprintf "Base sort mismatch: $ and $" [str_b b, str_b b']])
      | _ => raise unify_error "base sort" r (str_bs bs, str_bs bs')
  end
    
fun V r n = IVar (ID (n, r), [])
fun TV r n = TVar (ID (n, r))

open Util
       
fun find_injection (eq : 'a -> 'a -> bool) (xs : 'a list) (ys : 'a list) : int list option =
  let
    exception FindInjError
    fun f x =
      case findi (fn y => eq x y) ys of
          SOME (n, _) => n
        | NONE => raise FindInjError
  in
    SOME (map f xs)
    handle FindInjError => NONE
  end

exception UnifyAppUVarFailed of string
(* Try to see whether [i']'s variables are covered by the arguments applied to [x]. If so, then refine [x] with [i'], with the latter's variables replaced by the former's arguments. This may not be the most general instantiation, because [i']'s constants will be fixed for [x], although those constants may be arguments in a more instantiation. For example, unifying [x y 5] with [y+5] will refine [x] to be [fun y z => y+5], but a more general instantiation is [fun y z => y+z]. This less-general instantiation may cause later unifications to fail. *)
fun unify_IBApp r i i' =
  let
    val i = normalize_i i
    val ((x, _), args) = is_IBApp_IUVar i !! (fn () => raise UnifyAppUVarFailed "")
    val i' = normalize_i i'
    open CollectUVar
    val () = if mem op= x (map #1 $ collect_uvar_i_i i') then raise UnifyAppUVarFailed "" else ()
    val vars' = dedup eq_var $ collect_var_i_i i'

                      
    (* open CollectVar *)
    (* val uncovered = List.filter (fn var => not (List.exists (fn arg => eq_i (IVar var) arg) args)) vars' *)
    (* fun forget_nonconsuming (var as (m, (x, _))) b = *)
    (*   let *)
    (*     val () = if isNone m then () else raise UnifyAppUVarFailed *)
    (*     open UVarForget *)
    (*     val b = forget_i_i x 1 b *)
    (*     val b = shiftx_i_i x 1 b *)
    (*   in *)
    (*     b *)
    (*   end *)
    (* val i' = foldl (fn (x, acc) => forget_nonconsuming x acc) i' uncovered *)
    (*           handle ForgetError _ => raise UnifyAppUVarFailed *)
    (* val i' = normalize_i i' *)

                         
    val inj = find_injection eq_i (map (fn y => IVar (y, [])) vars') (rev args) !! (fn () => raise UnifyAppUVarFailed "")
    val i' = psubst_is_i vars' (map (V r) inj) i'
    val (name, ctx, b) = get_uvar_info x !! (fn () => raise Impossible "unify_IBApp(): shouldn't be [Refined]")
    val b = update_bs b
    (* val () = println $ str_bs b *)
    (* val () = println $ sprintf "unifying ?$" [str_int name] *)
    fun var_name n = "__x" ^ str_int n
    val (bsorts, _) = collect_BSArrow b
    val bsorts = rev bsorts
    (* val () = println $ str_ls str_bs bsorts *)
    val ext_ctx = mapi (mapFst var_name) bsorts
    val ctx = ext_ctx @ ctx
    val () = if length args <= length ctx then () else raise Impossible "unify_IBApp(): #args shouldn't be larger than #ctx"
    (* #args could be < #ctx because of partial application *)
    val ctx = lastn (length args) ctx
    fun IAbsMany (ctx, i, r) = foldl (fn ((name, b), i) => IAbs (b, Bind ((name, r), i), r)) i ctx
    val i' = IAbsMany (ctx, i', r)
    val () = refine x i'
  in
    ()
  end
    
fun unify_i r gctxn ctxn (i, i') =
  let
    val unify_i = unify_i r gctxn
    fun structural_compare (i, i') =
      let
        fun default () = 
          if eq_i i i' then ()
          else write_prop (PBinPred (BPEq (), i, i'), r)
      in
        if eq_i i i' then ()
        (* if one-side is not in a normal form because of uvar, we can't do structural comparison *)
        else if isSome (is_IBApp_IUVar i) orelse isSome (is_IBApp_IUVar i') then
          default ()
        else
        case (i, i') of
            (* ToReal is injective *)
            (IUnOp (IUToReal (), i, _), IUnOp (IUToReal (), i', _)) =>
            unify_i ctxn (i', i)
          | _ => default ()
      end
    val i = whnf_i i (* todo: whnf_i is enough *)
    val i' = whnf_i i'
    (* val () = println $ sprintf "Unifying indices $ and $" [str_i gctxn ctxn i, str_i gctxn ctxn i'] *)
    val () =
        (* first try unifying applications of uvars with the other index; if unsuccessful in both directions, then try ordinary structural unification *)
        unify_IBApp r i i'
        handle
        UnifyAppUVarFailed _ =>
        (unify_IBApp r i' i
         handle
         UnifyAppUVarFailed _ =>
         structural_compare (i, i'))
    (* val () = println "unify_i () ended" *)
  in
    ()
  end

open Bind
       
fun is_sub_sort r gctxn ctxn (s : sort, s' : sort) =
  let
    val is_sub_sort = is_sub_sort r gctxn
    val is_eqv_sort = is_eqv_sort r gctxn
    fun unify_SApp s s' =
      let
        val ((x, _), args) = is_SApp_SUVar s !! (fn () => raise UnifyAppUVarFailed "")
        val args = map normalize_i args
        val s' = normalize_s s'
        open CollectUVar
        val () = if mem op= x (map #1 $ collect_uvar_s_s s') then raise UnifyAppUVarFailed "" else ()
        val vars' = dedup eq_var $ collect_var_i_s s'
        val inj = find_injection eq_i (map (fn y => IVar (y, [])) vars') (rev args) !! (fn () => raise UnifyAppUVarFailed "")
        val s' = psubst_is_s vars' (map (V r) inj) s'
        val (_, ctx) = get_uvar_info x !! (fn () => raise Impossible "unify_s()/SApp: shouldn't be [Refined]")
        val () = if length args <= length ctx then () else raise Impossible "unify_SApp(): #args shouldn't be larger than #ctx"
        (* #args could be < #ctx because of partial application *)
        val ctx = lastn (length args) ctx
        val s' = SAbs_Many (rev ctx, s', r)
        val () = refine x s'
      in
        ()
      end
    fun structural_compare (s, s') =
      let
        fun default () = raise UnifyError (r, ["Sort"] @ indent [str_s gctxn ctxn s] @ ["is not a subsort of"] @ indent [str_s gctxn ctxn s'])
      in
        if eq_s s s' then ()
                            (* if one-side is not in a normal form because of uvar, we can't do structural comparison *)
        else if isSome (is_SApp_SUVar s) orelse isSome (is_SApp_SUVar s') then
          default ()
        else
        case (s, s') of
            (SBasic (bs, _), SBasic (bs', _)) =>
            unify_bs r (bs, bs')
          | (SSubset ((bs, r1), Bind ((name, _), p), _), SSubset ((bs', _), Bind (_, p'), _)) =>
            let
	      val () = unify_bs r (bs, bs')
              val () = open_sorting (name, SBasic (bs, r1))
	      (* val () = write_prop (p <-> p', r) *)
	      val () = write_prop (p --> p', r)
	      (* val () = write_prop (p' --> p, r) *)
              val () = close_n 1
            in
              ()
            end
          | (SSubset ((bs, r1), Bind ((name, _), p), _), SBasic (bs', _)) =>
            let
	      val () = unify_bs r (bs, bs')
              val () = open_sorting (name, SBasic (bs, r1))
	      (* val () = write_prop (p, r) *)
              val () = close_n 1
            in
              ()
            end
          | (SBasic (bs, r1), SSubset ((bs', _), Bind ((name, _), p), _)) =>
            let
	      val () = unify_bs r (bs, bs')
              val () = open_sorting (name, SBasic (bs, r1))
	      val () = write_prop (p, r)
              val () = close_n 1
            in
              ()
            end
          | (SAbs (b, Bind ((name, _), s), _), SAbs (b', Bind (_, s'), _)) =>
            let
	      val () = unify_bs r (b, b')
              val () = is_sub_sort (name :: ctxn) (s, s')
            in
              ()
            end
          | (SApp (s, i), SApp (s', i')) =>
            let
              val () = is_sub_sort ctxn (s, s')
              val () = unify_i r gctxn ctxn (i, i')
            in
              ()
            end
          | _ => default ()
      end
    val s = whnf_s s
    val s' = whnf_s s'
    (* val () = println $ sprintf "unifying sorts $ and $" [str_s gctxn ctxn s, str_s gctxn ctxn s'] *)
  in
    unify_SApp s s'
    handle
    UnifyAppUVarFailed _ =>
    (unify_SApp s' s
     handle
     UnifyAppUVarFailed _ =>
     structural_compare (s, s'))
  end

and is_eqv_sort r gctxn ctxn (s, s') =
  let
    val () = is_sub_sort r gctxn ctxn (s, s')
    val () = is_sub_sort r gctxn ctxn (s', s)
  in
    ()
  end
    
fun is_sub_sorts r gctx ctx (sorts, sorts') =
  (check_length r (sorts, sorts');
   ListPair.app (is_sub_sort r gctx ctx) (sorts, sorts'))

fun is_eqv_sorts r gctx ctx (sorts, sorts') =
  let
    val () = is_sub_sorts r gctx ctx (sorts, sorts')
    val () = is_sub_sorts r gctx ctx (sorts', sorts)
  in
    ()
  end

fun kind_mismatch expect str_got got = sprintf "Kind mismatch: expect $ got $" [expect, str_got got]
fun kind_mismatch_in_type expected str_got got thing =
  [sprintf "Kind mismatch:" [thing]] @ indent [sprintf "expected:\t $" [expected], sprintf "got:\t $" [str_got got], sprintf "in type:\t $" [thing]]

fun unify_k r (k as (ntargs, sorts), k' as (ntargs', sorts')) =
  let
    val () = check_eq r op= (ntargs, ntargs')
    val () = check_eq r op= (length sorts, length sorts')
    val () = app (unify_bs r) $ zip (sorts, sorts')
  in
    ()
  end
  handle UnifyError _ => raise UnifyError (r, [kind_mismatch (str_k k') str_k k])
                              
(*      
fun unify_kind r gctxn sctxn (k, k') =
    case (k, k') of
        (ArrowK (is_dt, ntargs, sorts), ArrowK (is_dt', ntargs', sorts')) =>
        let
          val () = check_eq r op= (is_dt, is_dt')
          val () = check_eq r op= (ntargs, ntargs')
          val () = unify_sorts r gctxn sctxn (sorts, sorts')
        in
          ()
        end
        handle UnifyError _ => raise UnifyError (r, [kind_mismatch gctxn sctxn (str_k gctxn sctxn k) k'])
*)

fun check_map_size r (a, b) =
  if StMap.numItems a = StMap.numItems b then
    ()
  else
    raise Error (r, ["Map size mismatch"])

fun unify_state r gctxn sctxn (st, st') =
  (check_map_size r (st, st');
   app (fn (k, v) => unify_i r gctxn sctxn (v, st' @!! k)) $ StMap.listItemsi st)
                               
fun unify_mt r gctx ctx (t, t') =
  let
    val unify_mt = unify_mt r gctx
    val sctx = #1 ctx
    val kctx = #2 ctx
    val gctxn = gctx_names gctx
    val ctxn as (sctxn, kctxn) = (sctx_names sctx, names kctx)
    fun unify_TApp t t' =
      let
        val ((x, _), i_args, t_args) = is_TApp_TUVar t !! (fn () => raise UnifyAppUVarFailed "is_TApp_TUVar() fails")
        (* val () = println $ "#i_args=" ^ str_int (length i_args) *)
        val i_args = map normalize_i i_args
        val t_args = map (normalize_mt true gctx kctx) t_args
        val t' = normalize_mt true gctx kctx t'
        val i_vars' = dedup eq_var $ collect_var_i_mt t'
        (* val () = println $ "t'=" ^ (str_mt gctxn ctxn t') *)
                                       
                                       
        open CollectVar
        val uncovered = List.filter (fn var => not (List.exists (fn arg => eq_i (IVar (var, [])) arg) i_args)) i_vars'
        fun forget_nonconsuming (var : var) b =
          let
            val x = case var of
                         ID (x, _) => x
                       | QID _ =>
                         raise UnifyAppUVarFailed "can't forget moduled variable"
            open UVarForget
            val b = normalize_mt true gctx kctx b
            val b = forget_i_mt x 1 b
            val b = shiftx_i_mt x 1 b
          in
            b
          end
        val t' = foldl (fn (x, acc) => forget_nonconsuming x acc) t' uncovered
                 handle ForgetError _ => raise UnifyAppUVarFailed "ForgetError"
        val t' = normalize_mt true gctx kctx t'

        (* val () = println $ "t'=" ^ (str_mt gctxn ctxn t') *)
        val t = normalize_mt true gctx kctx t
        val ((x, _), i_args, t_args) = is_TApp_TUVar t !! (fn () => raise UnifyAppUVarFailed "is_TApp_TUVar() fails")
        val () = if mem op= x (map #1 $ CollectUVar.collect_uvar_t_mt t') then raise UnifyAppUVarFailed "[x] is in [t']" else ()
        val i_vars' = dedup eq_var $ collect_var_i_mt t'
        val t_vars' = dedup eq_var $ collect_var_t_mt t'
        val i_inj = find_injection eq_i (map (fn y => IVar (y, [])) i_vars') (rev i_args) !! (fn () => raise UnifyAppUVarFailed "find_inject(i_args) failed")
        val t_inj = find_injection eq_mt (map TVar t_vars') (rev t_args) !! (fn () => raise UnifyAppUVarFailed "find_inject(t_args) failed")
        val () = assert (fn () => length t_vars' = length t_inj) "length t_vars' = length t_inj"
        val t' = psubst_ts_mt t_vars' (map (TV r) t_inj) t'
        val t' = psubst_is_mt i_vars' (map (V r) i_inj) t'
        val (uvar_name, (sctx, kctx)) = get_uvar_info x !! (fn () => raise Impossible "unify_TApp()/TApp: shouldn't be [Refined]")
        (* val () = println $ "sctx=" ^ str_ls fst sctx *)
        val () = if length i_args <= length sctx then () else raise Impossible "unify_TApp(): #i_args <> #sctx"
        (* #i_args could be < #sctx because of partial application *)
        val () = if length t_args <= length kctx then () else raise Impossible "unify_TApp(): #t_args shouldn't be larger than #kctx"
        (* #t_args could be < #kctx because of partial application *)
        (* val () = println $ "#i_args=" ^ str_int (length i_args) *)
        val sctx = lastn (length i_args) sctx
        val kctx = lastn (length t_args) kctx
        val t' = TAbs_Many (rev kctx, t', r)
        (* val () = println $ "sctx=" ^ str_ls fst sctx *)
        val t' = TAbsI_Many (rev sctx, t', r)
        (* val () = println $ str_mt empty ([], []) t' *)
        (* val () = println $ str_raw_mt t' *)
        (* val () = println $ sprintf "unify_TApp(): refine ?$ to be $" [str_int uvar_name, str_mt gctxn ctxn t'] *)
        val () = refine x t'
        (* val () = println "unify_TApp() succeeded" *)
      in
        ()
      end
    fun error ctxn (t, t') = unify_error "type" r (str_mt gctxn ctxn $ normalize_mt true gctx kctx t, str_mt gctxn ctxn $ normalize_mt true gctx kctx t')
    (* fun error ctxn (t, t') = unify_error "type" r (str_raw_mt t, str_raw_mt t') *)
    fun structural_compare (t, t') =
      let
        fun err () = raise error ctxn (t, t')
      in
      if eq_mt t t' then ()
      (* if one-side is not in a normal form because of uvar, we can't do structural comparison *)
      else if isSome (is_TApp_TUVar t) orelse isSome (is_TApp_TUVar t') then
        err ()
      else
      case t of
          TArrow ((st1, t1), (d, j), (st2, t2)) =>
          (case t' of
               TArrow ((st1', t1'), (d', j'), (st2', t2')) =>
               (unify_state r gctxn sctxn (st1, st1');
                unify_mt ctx (t1, t1');
                unify_i r gctxn sctxn (d, d');
                unify_i r gctxn sctxn (j, j');
                unify_state r gctxn sctxn (st2, st2');
                unify_mt ctx (t2, t2'))
             | _ => err ())
        | TArray (w, t, i) =>
          (case t' of
               TArray (w', t', i') =>
               (unify_i r gctxn sctxn (w, w');
                unify_mt ctx (t, t');
                unify_i r gctxn sctxn (i, i')
               )
             | _ => err ())
        | TNat (i, _) =>
          (case t' of
               TNat (i', _) =>
               unify_i r gctxn sctxn (i, i')
             | _ => err ())
        | TiBool (i, _) =>
          (case t' of
               TiBool (i', _) =>
               unify_i r gctxn sctxn (i, i')
             | _ => err ())
        (* | TProd (t1, t2) => *)
        (*   (case t' of *)
        (*        TProd (t1', t2') => *)
        (*        (unify_mt ctx (t1, t1'); *)
        (*         unify_mt ctx (t2, t2')) *)
        (*      | _ => err ()) *)
        | TUniI (s, Bind ((name, _), ((i, j), t1)), _) =>
          (case t' of
               TUniI (s', Bind (_, ((i', j'), t1')), _) =>
               let
                 val () = is_eqv_sort r gctxn sctxn (s, s')
               in
                 open_close add_sorting_sk (name, s) ctx
                            (fn ctx as (sctx, _) =>
                                let
                                  val sctxn = sctx_names sctx
                                in
                                  (unify_i r gctxn sctxn (i, i');
                                   unify_i r gctxn sctxn (j, j');
                                   unify_mt ctx (t1, t1'))
                                end)
               end
             | _ => err ())
        (* | (TSumbool (s1, s2), TSumbool (s1', s2')) => *)
        (*   (is_eqv_sort r gctxn sctxn (s1, s1'); *)
        (*    is_eqv_sort r gctxn sctxn (s2, s2')) *)
        | TUnit _ =>
          (case t' of
               TUnit _ => ()
             | _ => err ())
	| TBase (c, _) =>
          (case t' of
               TBase (c', _) => check_eq r op= (c, c')
             | _ => err ())
        | TAbs (k, Bind ((name, _), t), _) =>
          (case t' of
               TAbs (k', Bind (_, t'), _) =>
               let
                 val () = unify_k r (k, k')
                 val () = unify_mt (add_kinding_sk (name, k) ctx) (t, t')
               in
                 ()
               end
             | _ => err ())
        | TApp (t1, t2) =>
          (case t' of
               TApp (t1', t2') => 
               let
                 val () = unify_mt ctx (t1, t1')
                 val () = unify_mt ctx (t2, t2')
               in
                 ()
               end
             | _ => err ())
        | TAbsI (b, Bind ((name, _), t), _) =>
          (case t' of
               TAbsI (b', Bind (_, t'), _) =>
               let
                 val () = unify_bs r (b, b')
                 val () = open_close add_sorting_sk (name, SBasic (b, r)) ctx (fn ctx => unify_mt ctx (t, t'))
               in
                 ()
               end
             | _ => err ())
        | TAppI (t, i) =>
          (case t' of
               TAppI (t', i') => 
               let
                 val () = unify_mt ctx (t, t')
                 val () = unify_i r gctxn sctxn (i, i')
               in
                 ()
               end
             | _ => err ())
        (* now try a bit harder by not ignoring TDatatype when retrieving TVar *)
        | TVar _ =>
          (case t' of
               TDatatype _ => unify_mt ctx (whnf_mt false gctx kctx t, t')
             | TVar _ => unify_mt ctx (whnf_mt false gctx kctx t, whnf_mt false gctx kctx t')
             | _ => err ())
        | TDatatype (dt, _) =>
          (case t' of
               TVar _ => unify_mt ctx (t, whnf_mt false gctx kctx t')
             | TDatatype (dt', _) =>
               let
                 (* val () = println "structural TDatatypes compare started" *)
                 fun dt_error () = error ctxn (t, t')
                 fun check b = if b then () else raise dt_error ()
                 fun check_length (ls, ls') = check $ length ls = length ls'
                 val Bind (name, tbinds) = dt
                 val Bind (name', tbinds') = dt
                 (* the self-referencing name is significant *)
                 val () = check $ fst name = fst name'
                 val (tname_kinds, (bsorts, constr_decls)) = unfold_binds tbinds
                 val (tname_kinds', (bsorts', constr_decls')) = unfold_binds tbinds'
                 val () = check_length (tname_kinds, tname_kinds')
                 fun unify_bsorts p =
                   (check_length p;
                    ListPair.app (unify_bs r) p)
                 val () = unify_bsorts (bsorts, bsorts')
                 fun unify_is ctx p =
                   (check_length p;
                    ListPair.app (unify_i r gctxn $ sctx_names ctx) p)
                 fun unify_inner ctx ((t, is), (t', is')) =
                   (unify_mt ctx (t, t');
                    unify_is (#1 ctx) (is, is'))
                 fun unify_constr_decl ctx ((name, core, _), (name', core', _)) =
                   let
                     (* constructor names are significant *)
                     val () = check $ fst name = fst name'
                     fun unify_binds ctx (binds, binds') =
                       case (binds, binds') of
                           (BindNil inner, BindNil inner') => unify_inner ctx (inner, inner')
                         | (BindCons (s, Bind (name, binds)), BindCons (s', Bind (name', binds'))) =>
                           (is_eqv_sort r gctxn (sctx_names $ #1 ctx) (s, s');
                            open_close add_sorting_sk (fst name, s) ctx (fn ctx => unify_binds ctx (binds, binds')))
                         | _ => raise dt_error ()
                   in
                     unify_binds ctx (core, core')
                   end
                 fun unify_constr_decls ctx (ds, ds') =
                   (check_length (ds, ds');
                    ListPair.app (unify_constr_decl ctx) (ds, ds'))
                 val family_kind = (length tname_kinds, bsorts)
                 val new_kindings = rev $ (fst name, family_kind) :: map (fn (name, ()) => (fst name, Type)) tname_kinds
                 val () = unify_constr_decls (add_kindings_sk new_kindings ctx) (constr_decls, constr_decls')
                                             (* val () = println "structural TDatatypes compare finished" *)
               in
                 ()
               end
             | _ => err ())
        | TNatCell _ =>
          (case t' of
               TNatCell _ => ()
             | _ => err ())
        | TMap t =>
          (case t' of
               TMap t' => unify_mt ctx (t, t')
             | _ => err ())
        | TVector t =>
          (case t' of
               TVector t' => unify_mt ctx (t, t')
             | _ => err ())
        | TSCell t =>
          (case t' of
               TSCell t' => unify_mt ctx (t, t')
             | _ => err ())
        | TPtr t =>
          (case t' of
               TPtr t' => unify_mt ctx (t, t')
             | _ => err ())
        | TState x =>
          (case t' of
               TState x' => check_eq r op= (x, x')
             | _ => err ())
        | TRecord (t, _) =>
          (case t' of
               TRecord (t', _) =>
               ignore $ SMapU.check_equal err (unify_mt ctx) t t'
             | _ => err ()
          )
        | TTuple ts =>
          (case t' of
               TTuple ts' =>
               if length ts <> length ts' then
                 err ()
               else
                 app2 (unify_mt ctx) (ts, ts')
             | _ => err ()
          )
        | TUVar _ => err ()
      end
    fun more_uvar_args (a, b) =
      case (is_TApp_TUVar a, is_TApp_TUVar b) of
          (SOME (_, i_args, t_args), SOME (_, i_args', t_args')) =>
          length i_args > length i_args' andalso length t_args > length t_args'
        | _ => false
    val t = whnf_mt true gctx kctx t
    val t' = whnf_mt true gctx kctx t'
    (* val () = println $ sprintf "Unifying types\n\t$\n  and\n\t$" [str_mt gctxn ctxn t, str_mt gctxn ctxn t'] *)
    (* Apply [unify_TApp] in which order? Here is a heuristic: *)
    fun main () =
      let
        val (t_more, t_less) = if more_uvar_args (t', t) then
                                 (t', t)
                               else
                                 (t, t')
      in
        unify_TApp t_more t_less
        handle
        UnifyAppUVarFailed msg =>
        let
          (* val () = println ("(unify_TApp t t') failed because " ^ msg) *)
          val t_less = whnf_mt true gctx kctx t_less
        in
          unify_TApp t_less t_more
          handle
          UnifyAppUVarFailed msg =>
          let
            (* val () = println ("(unify_TApp t' t) failed because " ^ msg) *)
            val t = whnf_mt true gctx kctx t
            val t' = whnf_mt true gctx kctx t'
          in
            structural_compare (t, t')
          end
        end
      end
    fun extra_msg () = ["when unifying"] @ indent [str_mt gctxn ctxn t] @ ["and"] @ indent [str_mt gctxn ctxn t']
    val ret = main ()
              handle
              Error (r, msg) => raise Error (r, msg @ extra_msg ())
              | Impossible msg => raise Impossible $ join_lines $ msg :: extra_msg ()
    (* val () = println "unify_mt () ended" *)
  in
    ret
  end

fun unify_t r gctx ctx (t, t') =
  case (t, t') of
      (PTMono t, PTMono t') => unify_mt r gctx ctx (t, t')
    | (PTUni ((i, j), Bind ((name, _), t), _), PTUni ((i', j'), Bind (_, t'), _)) =>
      let
        val gctxn = gctx_names gctx
        val sctxn = sctx_names $ #1 ctx
      in
        (unify_i r gctxn sctxn (i, i');
         unify_i r gctxn sctxn (j, j');
         unify_t r gctx (add_kinding_sk (name, Type) ctx) (t, t'))
      end
    | _ =>
      let
        val gctxn = gctx_names gctx
        val ctxn = (sctx_names $ #1 ctx, names $ #2 ctx)
      in
        raise unify_error "poly-type" r (str_t gctxn ctxn t, str_t gctxn ctxn t')
      end
        
fun is_sub_kindext r gctx ctx (ke as (k, t), ke' as (k', t')) =
  let
    val gctxn = gctx_names gctx
    val sctxn = sctx_names $ #1 ctx
    val kctxn = names $ #2 ctx
    val () = unify_k r (k, k')
  in
    case (t, t') of
        (NONE, NONE) => ()
      | (SOME t, SOME t') => unify_mt r gctx ctx (t, t')
      | (SOME _, NONE) => ()
      | (_, _) => raise UnifyError (r, [sprintf "Kind $ is not a sub kind of $" [str_ke gctxn (sctxn, kctxn) ke, str_ke gctxn (sctxn, kctxn) ke']])
  end

end
