structure BigOSolver = struct
open UVarUtil
open VC
open NoUVarExpr
open Subst
open Simp
       
infixr 0 $

infix 9 %@
infix 7 %*
infix 6 %+
infix 4 %<=
infix 4 %>=
infix 4 %=
infixr 3 /\
infixr 2 \/
infixr 1 -->
infix 1 <->

infix 4 ==

fun TimeFun n =
  if n <= 0 then Base Time
  else BSArrow (Base Nat, TimeFun (n-1))

fun TimeAbs (name, i, r) = IAbs (Base Nat, Bind (name, i), r)
               
fun forget_i_vc x n (hs, p) = let
  fun f (h, (hs, x)) = 
      case h of 
          VarH _ => (h :: hs, x + 1) 
        | PropH p => (PropH (forget_i_p x 1 p) :: hs, x) handle ForgetError _ => (hs, x) (* just give up hypothesis if it involves [x] *)
  val (hs, x) = foldr f ([], 0) hs
in
  (hs, forget_i_p x 1 p)
end

fun match_bigO f hyps hyp =
    case hyp of
        PropH (BinPred (BigO, f', g)) =>
        if eq_i f' f then SOME g else NONE
      | _ => NONE
               
fun find_bigO_hyp f_i hyps =
    find_hyp (forget_i_i 0 1) shift_i_i match_bigO f_i hyps

fun appears forget x big = not $ isSome $ try_forget (forget x 1) big
fun contains big small = appears forget_i_i small big
                             
fun ask_smt_vc vc =
    not $ isSome $ SMTSolver.smt_solver_single "" false NONE vc
                                     
fun mult_class_entry ((c1, k1), (c2, k2)) = (c1 + c2, k1 + k2)
                                              
fun add_class_entry (a as (c1, k1), b as (c2, k2)) =
    if c1 = c2 then (c1, max k1 k2) else if c1 > c2 then a else b

val mult_class_entries = foldl' mult_class_entry (0, 0)
                                
val add_class_entries = foldl' add_class_entry (0, 0)

structure M = IntBinaryMap
                
val mult_class = M.unionWith mult_class_entry
                             
val add_class = M.unionWith add_class_entry
                            
val mult_classes = foldl' mult_class M.empty
                          
val add_classes = foldl' add_class M.empty

fun trim_class cls = M.filter (fn (c, k) => not (c = 0 andalso k = 0)) cls
                              
fun str_cls cls = str_ls (fn (x, (c, k)) => sprintf "$=>($,$)" [str_int x, str_int c, str_int k]) $ M.listItemsi $ cls
                     
(* summarize [i] in the form n_1^c_1 * (log n_1)^k_1 * ... * n_s^c_s * (log n_s)^k_s, and [n_1 => (c_1, k_1), ..., n_s => (c_s, k_s)] will be the [i]'s "asymptotic class". [n_1, ..., n_s] are the variable. *)
fun summarize (is_outer, on_error) i =
    let
      fun loop i = 
          case i of
              ConstIT _ =>
              M.empty
            | ConstIN _ =>
              M.empty
            | VarI (_, (x, _)) =>
              if is_outer x then
                M.empty
              else
                M.insert (M.empty, x, (1, 0))
            | UnOpI (B2n, i, _) =>
              M.empty
            | UnOpI (ToReal, i, _) =>
              loop i
            | UnOpI (Ceil, i, _) =>
              loop i
            | UnOpI (Floor, i, _) =>
              loop i
            | DivI (i, _) =>
              loop i
            | UnOpI (Log2, i, _) =>
              let
                (* val () = println "summarize/Log2" *)
                val is = collect_MultI i
                val classes = map loop is
                val cls = add_classes classes
                (* val () = println $ str_cls cls *)
                (* (0, 0) should never enter a class, so the following precaution shouldn't be necessary *)
                fun log_class (c, k) =
                    (* approximate [log (log n)] by [log n] *)
                    (0, if c = 0 andalso k = 0 then 0 else 1) 
                val cls = M.map log_class cls
                val cls = trim_class cls
                                     (* val () = println $ str_cls cls *)
              in
                cls
              end
            | BinOpI (MultI, a, b) =>
              mult_class (loop a, loop b)
            | BinOpI (AddI, a, b) =>
              add_class (loop a, loop b)
            | BinOpI (BoundedMinusI, a, b) =>
              loop a
            | BinOpI (MaxI, a, b) =>
              add_class (loop a, loop b)
            | _ => on_error $ "summarize fails with " ^ str_i [] [] i
    in
      loop i
    end

fun class_entry_le ((c, k), (c', k')) =
    if c < c' then
      true
    else if c = c' then k <= k'
    else false

fun class_le (m1, m2) =
    let
      fun f (k1, v1, still_ok) =
          if still_ok then
            let
              val v2 = default (0, 0) $ M.find (m2, k1)
            in
              class_entry_le (v1, v2)
            end
          else
            false
    in
      M.foldli f true m1
    end
      
(* if [i] is [f n] or [f m n] where [f]'s bigO spec is known, replace [f] with its bigO spec *)
fun use_bigO_hyp is_outer long_hyps i =
    case i of
        BinOpI (IApp, f_i, n') =>
        (case f_i of
             VarI (_, (f, _)) =>
             if is_outer f then
               case find_bigO_hyp f_i long_hyps of
                   SOME (g, _) => simp_i (g %@ n')
                 | NONE => i
             else i
           | BinOpI (IApp, f_i as VarI (_, (f, _)), m') =>
             if is_outer f  then
               case find_bigO_hyp f_i long_hyps of
                   SOME (g, _) => simp_i (g %@ m' %@ n')
                 | NONE => i
             else i
           | _ => i
        )
      | _ => i
                           
fun timefun_le hs arity a b =
    let
      fun match_bigO () hyps hyp =
          case hyp of
              PropH (BinPred (BigO, f', g)) =>
              SOME (f', g)
            | _ => NONE
      fun find_bigO_hyp f_i hyps =
          find_hyp id (fn (a, b) => (shift_i_i a, shift_i_i b)) match_bigO () hyps
      fun use_bigO_hyp long_hyps i =
          case find_bigO_hyp i long_hyps of
              SOME ((VarI (_, (f', _)), g), _) =>
              let
                val g = simp_i g
                val i' = simp_i $ substx_i_i f' g i
                (* val ctx = hyps2ctx hs *)
                (* val () = println $ sprintf "timefun_le(): $ ~> $" [str_i [] ctx i, str_i [] ctx i'] *)
              in
                i'
              end
            | _ => i
      exception Error of string
      fun main () =
          let
            val a = if arity <= 2 then
                     use_bigO_hyp hs a
                   else
                     a
            val (names1, i1) = collect_IAbs a
            val (names2, i2) = collect_IAbs b
            val () = if length names1 = length names2 then () else raise Error "timefun_le: arity must equal"
            val summarize = summarize (fn x => x >= length names1, fn s => raise Error s)
            val cls1 = summarize i1
            val cls2 = summarize i2
            (* val () = println $ sprintf "$ <=? $" [str_cls cls1, str_cls cls2] *)
          in
            class_le (cls1, cls2)
          end
    in
      main ()
      handle
      Error msg =>
      let
        val () = println $ sprintf "timefun_le failed because: $" [msg]
      in
        false
      end
    end

fun timefun_eq hs arity a b = timefun_le hs arity a b andalso timefun_le hs arity b a
      
fun by_master_theorem hs (name1, arity1) (name0, arity0) vcs =
    let
      exception Error of string
      fun runError m _ =
          let
            val ret as f = m ()
            val ctx = List.mapPartial (fn h => case h of VarH (name, _) => SOME name | _ => NONE) hs
            val () = println $ sprintf "Yes! I solved this: $\n" [str_i [] ctx f]
          in
            SOME ret
          end
          handle
          Error msg =>
          let
            val () = printf "Oh no! I can't solve this because: $\n" [msg]
          in
            NONE
          end
      fun infer_vc (vc as (short_hyps, p), long_hyps) =
          let
            (* VarI (main_fun, _) is the time function of interest in the Master Theorem *)
            val main_fun = length $ hyps2ctx short_hyps
            (* variables satisfy [is_outer] is considered constants in the outer environment *)
            fun is_outer x = x >= main_fun + 2
            fun ask_smt p = ask_smt_vc (long_hyps, p)
            val N1 = ConstIN (1, dummy)
            fun V n = VarI (NONE, (n, dummy))
            fun to_real i = UnOpI (ToReal, i, dummy)
            fun exp n i = combine_MultI (repeat n i)
            fun class2term (c, k) n =
                exp c n %* exp k (UnOpI (Log2, n, dummy))
            fun master_theorem n (a, b) (c, k) =
                let
                  val int_add = op+
                  open Real
                  val log_b_a = Math.ln (fromInt a) / Math.ln (fromInt b)
                  val T =
                      if fromInt c < log_b_a then
                        ExpI (n, (toString log_b_a, dummy))
                      else if fromInt c == log_b_a then
                        class2term (c, int_add (k, 1)) n
                      else if fromInt c > log_b_a then
                        class2term (c, k) n
                      else raise Error "can't compare c and (log_b a)"
                in
                  T
                end
            fun get_params is_sub_problem is =
                let
                  (* find terms of the form [T m (ceil (n/b))] (or respectively for [floor]) *)
                  val (bs, others) = partitionOption is_sub_problem is
                  val a = length bs
                  val b = if null bs then raise Error "bs is null" else hd bs
                  val () = if List.all (curry op= (b : int)) (tl bs) then () else raise Error "all bs eq"
                in
                  (a, b, others)
                end
            fun extract_only_variable error cls =
                let
                  val cls = M.listItemsi $ trim_class cls
                  (* val () = println $ str_ls (fn (x, (c, k)) => sprintf "$=>($,$)" [str_int x, str_int c, str_int k]) $ cls *)
                  val x = if length cls <> 1 orelse snd (hd cls) <> (1, 0) then raise error
                          else fst (hd cls)
                in
                  x
                end
            (* a version of [summarize] where n = O(x) is linear with the only variable x. *)
            fun summarize_1 n i =
                let
                  val error = Error
                  fun on_error s = raise error s
                  val summarize = summarize (is_outer, on_error)
                  val cls_n = summarize n
                  val cls_i = M.listItemsi $ trim_class $ summarize i
                  fun get_x () = extract_only_variable (error "summarize_1: class of n must be (1, 0) for only one variable") cls_n
                  fun err () = on_error "summarize_1: class of i must only contain n's variable"
                  val ret = if length cls_i = 0 then
                              (0, 0)
                            else if length cls_i = 1 then
                              let
                                val x = get_x ()
                                val x' = fst (hd cls_i)
                                val cls = snd (hd cls_i)
                              in
                                if x' = x then
                                  cls
                                else
                                  if ask_smt $ (* trace ("V x' %<= n ?") $  *)(V x' %<= n) then
                                    cls
                                  else
                                    err ()
                              end
                            else err ()
                in
                  ret
                end
            (* a version of [summarize] where n = O(x) and m = O(y), x <> y, and i = y * f(x) or f(x) *)
            fun summarize_2 m n i =
                let
                  val error = Error
                  fun on_error s = raise error s
                  val summarize = summarize (is_outer, on_error)
                  val cls_n = summarize n
                  val cls_m = summarize m
                  val cls_i = M.listItemsi $ trim_class $ summarize i
                  fun err () = on_error $ "summarize_2: i should be y*f(x) or f(x) " ^ str_i [] [] i
                  fun get_y () = extract_only_variable (error "summarize_2: class of n must be (1, 0) for only one variable") cls_m
                  fun get_x () = extract_only_variable (Error $ "summarize_2: class of n must be (1, 0) for only one variable " ^ str_i [] [] n) cls_n
                  fun check_x_neq_y (x : int) y = if x = y then on_error "summarize_2: x = y" else ()
                  val ret = if length cls_i = 0 then
                              (0, 0)
                            else if length cls_i = 1 then
                              let
                                val y = get_y ()
                              in
                                if fst (hd cls_i) = y then (0, 0)
                                else
                                  let
                                    val x = get_x ()
                                    val () = check_x_neq_y x y
                                  in
                                    if fst (hd cls_i) = x then snd (hd cls_i)
                                    else err ()
                                  end
                              end
                            else if length cls_i = 2 then
                              let
                                val y = get_y ()
                                val x = get_x ()
                                val () = check_x_neq_y x y
                                val ((v1, c1), (v2, c2)) =
                                    case cls_i of
                                        a :: b :: _ => (a, b)
                                      | _ => raise Impossible "length cls_i = 2"
                                val (cx, cy) = if v1 = x andalso v2 = y then (c1, c2)
                                               else if v2 = x andalso v1 = y then (c2, c1)
                                               else err ()
                                val () = if cy = (1, 0) then () else err ()
                              in
                                cx
                              end
                            else err ()
                in
                  ret
                end
            val use_bigO_hyp = use_bigO_hyp is_outer long_hyps
            fun infer_b n_ n' =
                let
                  fun infer_b_i i =
                      case i of
                          UnOpI (_, i, _) => infer_b_i i 
                        | DivI (_, (b, _)) => [b]
                        | _ => []
                  fun infer_b_p p =
                      case p of
                          BinPred (EqP, i1, i2) => infer_b_i i1 @ infer_b_i i2
                        | _ => []
                  fun infer_b_hyp h =
                      case h of
                          PropH p => infer_b_p p
                        | VarH _ => []
                  val bs = infer_b_i n' @ concatMap infer_b_hyp long_hyps
                  fun good_b b =
                      if ask_smt (n' %<= UnOpI (Ceil, DivI (n_, (b, dummy)), dummy)) then
                        SOME b
                      else NONE
                in
                  firstSuccess good_b bs
                end
            fun simp_i_max set i =
                let
                  fun mark a = (set (); a)
                  fun loop i =
                      case i of
                          BinOpI (opr, i1, i2) =>
                          let
                            fun def () = BinOpI (opr, loop i1, loop i2)
                          in
                            case opr of
                                MaxI =>
                                if ask_smt (i1 %>= i2) then
                                  mark i1
                                else if ask_smt (i1 %<= i2) then
                                  mark i2
                                else def ()
                              | _ => def ()
                          end
                        | UnOpI (opr, i, r) => UnOpI (opr, loop i, r)
                        | DivI (i, b) => DivI (loop i, b)
                        | ExpI (i, e) => ExpI (loop i, e)
                        | Ite (i1, i2, i3, r) => Ite (loop i1, loop i2, loop i3, r)
                        | IAbs _ => i
	                | TrueI _ => i
	                | FalseI _ => i
	                | TTI _ => i
                        | ConstIN _ => i
                        | ConstIT _ => i
                        | VarI _ => i
                        | AdmitI _ => i
                        | UVarI _ => i
                in
                  loop i
                end
            fun simp_p_max set p =
                let
                  fun loop p =
                      case p of
                          BinPred (opr, i1, i2) => BinPred (opr, simp_i_max set i1, simp_i_max set i2)
                        | BinConn (opr, p1, p2) => BinConn (opr, loop p1, loop p2)
                        | Not (p, r) => Not (loop p, r)
                        | True _ => p
                        | False _ => p
                        | Quan _ => p
                in
                  loop p
                end
            val p = simp_p_with_plugin simp_p_max p
          in
            case p of
                BinPred (LeP, i1, BinOpI (IApp, BinOpI (IApp, VarI (_, (g, _)), VarI (_, (m, _))), n_i)) =>
                let
                  val () = if g = main_fun then () else raise Error "g = main_fun fails"
                  val () = if m < main_fun then () else raise Error "m < main_fun fails"
                  (* ToDo: check that [n_i] are well-scoped in [hs'] *)
                  (* ToDo: check that [m] doesn't appear in [n_i] *)
                  val m_i = V m
                  val m_ = to_real m_i
                  val n_ = to_real n_i
                in
                  (* test the case: a * T m (n/b) + f m n <= T m n  *)
                  let
                    val is = collect_AddI i1
                    fun is_sub_problem i =
                        case i of
                            BinOpI (IApp, BinOpI (IApp, VarI (NONE, (g', _)), VarI (_, (m', _))), n') =>
                            if g' = g andalso m' = m then
                              infer_b n_ n'
                            else NONE
                          | _ => NONE
                    val (a, b, others) = get_params is_sub_problem is
                    val () = if b > 1 then () else raise Error "b > 1"
                    val others = map use_bigO_hyp others
                    val classes = map (summarize_2 m_ n_) others
                    val (c, k) = add_class_entries classes
                    val T = master_theorem (to_real (V 0)) (a, b) (c, k)
                    val T = TimeAbs (("m", dummy), TimeAbs (("n", dummy), simp_i (to_real (V 1) %* T), dummy), dummy)
                    val ret = T
                  in
                    ret
                  end
                  handle
                  Error msg =>
                  (* test the case: T m n + m + C <= T m (n + 1) *)
                  let
                    val () = println $ sprintf "Failed the [T m (n/b)] case because: $" [msg]
                    val () = println "Try [T m (n-1)] case ..."
                    (* val () = println $ sprintf "main_fun=$   g=$" [str_int main_fun, str_int g] *)
                    val is = collect_AddI i1
                    fun par i =
                        case i of
                            BinOpI (IApp, BinOpI (IApp, VarI (_, (g', _)), VarI (_, (m', _))), n') =>
                            let
                              (* val () = println $ sprintf "main_fun=$   g=$  g'=$" [str_int main_fun, str_int g, str_int g'] *)

                            in
                              if g' = g andalso m' = m then
                                SOME n'
                              else NONE
                            end
                          | _ => NONE
                    val (n's, rest) = partitionOption par is
                    val () = if null n's then raise Error "n's is null" else ()
                    (* val () = println $ sprintf "length n's = $" [str_int $ length n's] *)
                    val n' = combine_AddI_Nat n's
                    val () = if ask_smt (n' %+ N1 %<= n_i) then () else raise Error "n' %+ N1 %<= n_i"
                    val (c, k) =
                        add_class_entries $ map (summarize_2 m_ n_ o use_bigO_hyp) rest
                    val Tn = class2term (c + 1, k) (to_real (V 0))
                    val ret = TimeAbs (("m", dummy), TimeAbs (("n", dummy), simp_i (to_real (V 1) %* Tn), dummy), dummy)
                  in
                    ret
                  end
                end
              | BinPred (LeP, i1, BinOpI (IApp, VarI (_, (g, _)), n_i)) =>
                if not $ contains i1 g then
                  let
                    val () = if g = main_fun then () else raise Error "g = main_fun fails"
                    val n_ = to_real n_i
                    val is = collect_AddI i1
                    val is = map use_bigO_hyp is
                    val classes = map (summarize_1 n_) is
                    val cls = add_class_entries classes
                    val T = TimeAbs (("n", dummy), simp_i $ class2term cls (to_real (V 0)), dummy)
                  in
                    T
                  end
                else
                  let
                    val () = if g = main_fun then () else raise Error "g = main_fun fails"
                    (* ToDo: check that [n_i] are well-scoped in [hs'] *)
                    val n_ = to_real n_i
                  in
                    (* test the case: a * T (n/b) + f n <= T n  *)
                    let
                      val is = collect_AddI i1
                      fun is_sub_problem i =
                          case i of
                              BinOpI (IApp, VarI (_, (g', _)), n') =>
                              if g' = g then
                                infer_b n_ n'
                              else
                                NONE
                              (* BinOpI (IApp, VarI (g', _), UnOpI (opr, DivI (n', (b, _)), _)) => *)
                              (* if g' = g andalso (opr = Ceil orelse opr = Floor) andalso ask_smt (n' %= n_ \/ n' %+ T1 dummy %= n_) then *)
                              (*   SOME b *)
                              (* else NONE *)
                            | _ => NONE
                      val (a, b, others) = get_params is_sub_problem is
                      val () = if b > 1 then () else raise Error "b > 1"
                      (* if [i] is [f n] where [f]'s bigO spec is known, replace [f] with its bigO spec *)
                      val others = map use_bigO_hyp others
                      val classes = map (summarize_1 n_) others
                      val (c, k) = add_class_entries classes
                      val T = master_theorem (to_real (V 0)) (a, b) (c, k)
                      val T = TimeAbs (("n", dummy), simp_i T, dummy)
                      val ret = T
                    in
                      ret
                    end
                    handle
                    Error msg =>
                    (* test the case: T n + C <= T (n + 1) *)
                    let
                      val () = printf "Failed the [T (n/b)] case because: $\nTry [T (n-1)] case ...\n" [msg]
                      (* val i1 = simp_i i1 *)
                      val is = collect_AddI i1
                      fun par i =
                          case i of
                              BinOpI (IApp, VarI (_, (g', _)), n') =>
                              if g' = g then
                                SOME n'
                              else NONE
                            | _ => NONE
                      val (n's, rest) = partitionOption par is
                      val n' = combine_AddI_Nat n's
                      val () = if ask_smt (n' %+ N1 %<= n_i) then () else raise Error "n' %+ N1 %<= n_i"
                      val rest = map use_bigO_hyp rest
                      (* val () = println $ str_i [] (hyps2ctx long_hyps) $ combine_AddI_Time rest *)
                      val (c, k) =
                          add_class_entries $ map (summarize_1 n_) rest
                      val Tn = class2term (c + 1, k) (to_real (V 0))
                      val ret = TimeAbs (("n", dummy), simp_i Tn, dummy)
                    in
                      ret
                    end
                  end
              | _ => raise Error "wrong pattern for by_master_theorem"
          end
      fun main () =
          let
            val () = println "by_master_theorem ()"
            fun extend_vcs_with_long_hyps vcs = append_hyps ([VarH (name0, TimeFun arity0), VarH (name1, TimeFun arity1)] @ hs) vcs
            val vcs_with_long_hyps = extend_vcs_with_long_hyps vcs
            val vcs_and_long_hyps = map (fn (vc, (long_hyps, _)) => (vc, long_hyps)) $ zip (vcs, vcs_with_long_hyps)
            (* val () = println "Master-Theorem-solver to solve this: " *)
            (* val () = app println $ concatMap (fn ((_, p), long_hyps) => str_vc false "" (long_hyps, p) @ [""]) $ vcs_and_long_hyps *)
            val fs = map infer_vc vcs_and_long_hyps
            val (f, fs) = case fs of
                              [] => raise Error "by_master_theorem: no VCs"
                            | f :: fs => (f, fs)
            fun combine (a, b) =
                if timefun_eq hs arity1 a b then b
                else raise Error "by_master_theorem: inferred results don't agree"
            val f = foldl' combine f fs
          in
            f
          end
    in
      runError main ()
    end

fun use_master_theorem hs name_arity1 (name0, arity0) p =
    (* opportunity to apply the Master Theorem to infer the bigO class *)
    let
      val () = println "use_master_theorem ()"
      (* hoist the conjuncts that don't involve the time functions *)
      val vcs = prop2vcs p
      (* val () = println "after prop2vcs()" *)
      val (rest, vcs) = partitionOption (Option.composePartial (try_forget (forget_i_vc 0 1), try_forget (forget_i_vc 0 1))) vcs
      (* val () = println "after partitionOption()" *)
      val vcs = concatMap prop2vcs $ map (simp_p o vc2prop) vcs
      (* val () = println "after concatMap prop2vcs ()" *)
      val ret = by_master_theorem hs name_arity1 (name0, arity0) vcs
    in
      case ret of
          SOME i => SOME (i, append_hyps hs rest)
        | NONE => NONE
    end
      
fun split_and p =
    case p of
        BinConn (And, p1, p2) => (p1, p2)
      | _ => (p, True dummy)
               
fun infer_exists hs (name_arity1 as (name1, arity1)) p =
    let
      (* val () = println "infer_exists() to solve this: " *)
      (* val () = app println $ (str_vc false "" (VarH (name1, TimeFun arity1) :: hs, p) @ [""]) *)
    in
      if arity1 = 0 then
        (* just to infer a Time *)
        (case p of
             BinPred (Le, i1 as (ConstIT _), VarI (_, (x, _))) =>
             if x = 0 then SOME (i1, []) else NONE
           | _ => NONE
        )
      else
        case p of
            Quan (Exists _, bs, Bind ((name0, _), BinConn (And, bigO as BinPred (BigO, VarI (_, (n0, _)), VarI (_, (n1, _))), BinConn (Imply, bigO', p))), _) =>
            (case is_time_fun bs of
                 SOME arity0 =>
                 if n0 = 0 andalso n1 = 1 andalso eq_p bigO bigO' then
                   use_master_theorem hs name_arity1 (name0, arity0) p
                 else NONE
               | NONE => NONE
            )
          | BinPred (BigO, VarI (_, (x, _)), f) =>
            if x = 0 then
              let
                val () = println "No other constraint on function"
              in
                SOME (f, [])
              end
            else NONE
          | _ => NONE
    end
      
exception MasterTheoremCheckFail of region * string list
                                                    
fun solve_exists (vc as (hs, p)) =
    case p of
        Quan (Exists ins, bs, Bind ((name, _), p), _) =>
        (case is_time_fun bs of
             SOME arity =>
             let
               val ret =
                   case p of
                       BinConn (And, bigO as BinPred (BigO, VarI (_, (n0, _)), spec), BinConn (Imply, bigO', p)) =>
                       let
                         (* val ctxn = name :: hyps2ctx hs *)
                         (* val () = println $ sprintf "$\n$" [str_p ctxn bigO, str_p ctxn bigO'] *)
                       in
                         if n0 = 0 andalso eq_p bigO bigO' then
                           (* infer and then check *)
                           let
                             val () = println "Infer and check ..."
                           in
                             case use_master_theorem hs ("inferred", arity) (name, arity) (shiftx_i_p 1 1 p) of
                                 SOME (inferred, vcs) =>
                                 (let
                                   val inferred = forget_i_i 1 1 inferred
                                   val vcs = map (forget_i_vc 1 1) vcs
                                   val inferred = forget_i_i 0 1 inferred
                                   val spec = forget_i_i 0 1 spec
                                   val ctxn = hyps2ctx hs
                                   val () = println $ sprintf "Inferred! Now check inferred complexity $ against specified complexity $"
                                                    [str_i [] ctxn inferred, str_i [] ctxn spec]
                                   val ret = 
                                       if timefun_le hs arity inferred spec then
                                         SOME vcs
                                       else
                                         raise curry MasterTheoremCheckFail (get_region_i spec) $ [sprintf "Can't prove that the inferred big-O class $ is bounded by the given big-O class $" [str_i [] (hyps2ctx hs) inferred, str_i [] (hyps2ctx hs) spec]]
                                   val () = println "Complexity check OK!"
                                 in
                                   ret
                                 end
                                  handle
                                  ForgetError _ =>
                                  let
                                    val () = println "Complexity check Failed!"
                                  in
                                    NONE
                                  end)
                               | NONE => NONE
                           end
                         else NONE
                       end
                     | _ => NONE
               val ret = 
                   case ret of
                       SOME vcs => SOME vcs
                     | NONE =>
                       let
                       in
                         case infer_exists hs (name, arity) p of
                             SOME (i, vcs) =>
                             let
                               val () = println "Inferred by infer_exists():"
                               val () = println $ sprintf "$ = $" [name, str_i [] [] i]
                               val () = case ins of
                                            SOME ins => ins i
                                          | NONE => ()
                             in
                               SOME vcs
                             end
                           | NONE => NONE
                       end
               val ret = 
                   case ret of
                       SOME vcs => SOME vcs
                     | NONE =>
                       let
                         (* ToDo: a bit unsound inference strategy: infer [i] from [p1] and substitute for [i] in [p2] (assuming that [p2] doesn't contribute to inferring [i]) *)
                         val (p1, p2) = split_and p
                         val () = println "This inference may be unsound. "
                                          (* val () = println $ sprintf "It assumes this proposition doesn't contribute to inference of $:" [name] *)
                                          (* val () = app println $ (str_vc false "" (VarH (name, TimeFun arity) :: hs, p2) @ [""]) *)
                                          (* val () = println "and it only uses this proposition to do the inference:" *)
                                          (* val () = app println $ (str_vc false "" (VarH (name, TimeFun arity) :: hs, p1) @ [""]) *)
                                          (* val () = println "solve_exists() to solve this: " *)
                                          (* val () = app println $ (str_vc false "" vc @ [""]) *)
                       in
                         case infer_exists hs (name, arity) p1 of
                             SOME (i, vcs1) =>
                             let
                               val () = println "Inferred by infer_exists():"
                               val () = println $ sprintf "$ = $" [name, str_i [] [] i]
                               val () = case ins of
                                            SOME ins => ins i
                                          | NONE => ()
                               val p2 = subst_i_p i p2
                               val vcs = prop2vcs p2
                               val vcs = append_hyps hs vcs
                               val vcs = concatMap solve_exists vcs
                               val vcs = vcs1 @ vcs
                             in
                               SOME vcs
                             end
                           | NONE => NONE
                       end
             in
               case ret of
                   SOME vcs => vcs
                 | NONE => [vc]
             end
           | NONE => [vc]
        )
      | _ => [vc]

fun solve_bigO_compare (vc as (hs, p)) =
    case p of
        BinPred (BigO, i1, i2) =>
        let
          (* val () = println "BigO-compare-solver to solve this: " *)
          (* val () = app println $ str_vc false "" vc @ [""] *)
          fun get_arity i = length $ fst $ collect_IAbs i
          val arity = get_arity i2
          val result = timefun_le hs arity i1 i2
          (* val () = println $ sprintf "bigO-compare result: $" [str_bool result] *)
        in
          if result then
            []
          else
            [vc]
        end
      | _ => [vc]
               
fun solve_fun_compare (vc as (hs, p)) =
    case p of
        BinPred (Le, i1, i2) =>
        let
          fun find_apps i =
              let
                val is = collect_AddI i
                fun par i =
                    case i of
                        BinOpI (IApp, VarI (f, _), n) =>
                        SOME (f, n)
                      | _ => NONE
                val (apps, rest) = partitionOption par is
                val rest = combine_AddI_Time rest
              in
                (apps, rest)
              end
          val (apps1, rest1) = find_apps i1
          val (apps2, rest2) = find_apps i2
        in
          case (apps1, apps2) of
              ([(f1, n1)], [(f2, n2)]) =>
              if f1 = f2 then
                [(hs, n1 %<= n2), (hs, rest1 %<= rest2)]
              else
                [vc]
            | _ => [vc]
        end
      | _ => [vc]
               
fun solve_vcs (vcs : vc list) : vc list =
    let 
      val () = println "solve_vcs ()"
      val vcs = concatMap solve_exists vcs
      val vcs = concatMap solve_bigO_compare vcs
      val vcs = concatMap solve_fun_compare vcs
    in
      vcs
    end

end