(* EVM1 typechecking *)

structure EVM1Typecheck = struct

open MicroTiMLTypecheck
open CompilerUtil
open EVM1

infixr 0 $

infix 9 %@
infix 8 %^
infix 7 %*
infix 6 %+ 
infix 4 %<=
infix 4 %<
infix 4 %>=
infix 4 %=
infixr 3 /\
infixr 2 \/
infixr 1 -->
infix 1 <->

infixr 5 @::
infixr 5 @@
infix  6 @+
infix  9 @!

val T0 = T0 dummy
val T1 = T1 dummy

fun kc_against_KType ctx t = kc_against_kind ctx (t, KType)
                                             
fun add_sorting_full new ((ictx, tctx), rctx) = ((new :: ictx, tctx), Rctx.map (* lazy_ *)shift01_i_t rctx)
fun add_kinding_full new ((ictx, tctx), rctx) = ((ictx, new :: tctx), Rctx.map (* lazy_ *)shift01_t_t rctx)
fun add_r p (itctx, rctx) = (itctx, rctx @+ p)

fun get_word_const_type hctx c =
  case c of
      WCTT => TUnit
    | WCNat n => TNat $ INat n
    | WCInt _ => TInt
    | WCBool _ => TBool
    | WCByte _ => TByte
    | WCLabel l =>
      (case hctx @! l of
           SOME t => t
         | NONE => raise Impossible $ "unbound label: " ^ str_int l
      )

fun tc_w hctx (ctx as (itctx as (ictx, tctx))) w =
  case w of
      WConst c => get_word_const_type hctx c
    | WUninit t => kc_against_kind itctx (t, KType)
    | WBuiltin (name, t) => kc_against_kind itctx (t, KType)
    | WNever t => kc_against_kind itctx (t, KType)

fun is_reg_addr num_regs n =
  if n mod 32 = 0 then
    let
      val n = n div 32
    in
      (* r0 (n=1) is for scratch space of builtin macros and can't be explicitly accessed as a register *)
      if (* 1 *)2 <= n andalso n <= num_regs then SOME $ n-1
      else NONE
    end
  else NONE
         
fun tc_inst (hctx, num_regs) (ctx as (itctx as (ictx, tctx), rctx, sctx)) inst =
  let
    fun arith int_result nat_result name f time =
      let
        val (t0, t1, sctx) = assert_cons2 sctx
        val t =
            case (t0, t1) of
                (TConst TCInt, TConst TCInt) => int_result
              | (TNat i0, TNat i1) => nat_result $ f (i0, i1)
              | _ => raise Impossible $ sprintf "$: can't operate on operands of types $ and $" [name, str_t t0, str_t t1]
      in
        ((itctx, rctx, t :: sctx), time)
      end
    fun mul_div a = arith TInt TNat a
    fun cmp a = arith TBool TiBool a
    fun and_or name f time =
      let
        val (t0, t1, sctx) = assert_cons2 sctx
        val t =
            case (t0, t1) of
                (TConst TCBool, TConst TCBool) => TBool
              | (TiBool i0, TiBool i1) => TiBool $ f (i0, i1)
              | _ => raise Impossible $ sprintf "$: can't operate on operands of types $ and $" [name, str_t t0, str_t t1]
      in
        ((itctx, rctx, t :: sctx), time)
      end
  in
  case inst of
      ADD =>
      let
        val (t0, t1, sctx) = assert_cons2 sctx
        val t =
            case (t0, t1) of
                (TConst TCInt, TConst TCInt) => TInt
              | (TNat i0, TNat i1) => TNat $ i1 %+ i0
              | (TNat i, TTuplePtr (ts, offset)) => TTuplePtr (ts, offset %+ i)
              | (TTuplePtr (ts, offset), TNat i) => TTuplePtr (ts, offset %+ i)
              | (TNat i, TArrayPtr (t, len, offset)) => TArrayPtr (t, len, offset %+ i)
              | (TArrayPtr (t, len, offset), TNat i) => TArrayPtr (t, len, offset %+ i)
              | _ => raise Impossible $ sprintf "ADD: can't add operands of types $ and $" [str_t t0, str_t t1]
      in
        ((itctx, rctx, t :: sctx), T_ADD)
      end
    | SUB =>
      let
        val (t0, t1, sctx) = assert_cons2 sctx
        fun a %%- b = (write_prop (a %>= b); a %- b)
        val t =
            case (t0, t1) of
                (TConst TCInt, TConst TCInt) => TInt
              | (TNat i0, TNat i1) => TNat $ i0 %%- i1
              | (TTuplePtr (ts, offset), TNat i) => TTuplePtr (ts, offset %%- i)
              | (TArrayPtr (t, len, offset), TNat i) => TArrayPtr (t, len, offset %%- i)
              | _ => raise Impossible $ sprintf "SUB: can't subtract operands of types $ and $" [str_t t0, str_t t1]
      in
        ((itctx, rctx, t :: sctx), T_SUB)
      end
    | MUL => mul_div "MUL" op%* T_MUL
    | DIV => mul_div "DIV" op%/ T_DIV
    | SDIV => mul_div "SDIV" op%/ T_SDIV
    | MOD => mul_div "MOD" op%mod T_MOD
    | LT => cmp "LT" op%<? T_LT
    | GT => cmp "GT" op%>? T_GT
    | LE => cmp "LE" op%<=? T_LE
    | GE => cmp "GE" op%>=? T_GE
    | EQ => cmp "EQ" op%=? T0
    | ISZERO =>
      let
        val (t0, sctx) = assert_cons sctx
        val t =
            case t0 of
                TConst TCBool => TBool
              | TConst TCInt => TBool
              | TiBool i0 => TiBool $ INeg i0
              | _ => raise Impossible $ sprintf "ISZERO: can't operate on operand of type $" [str_t t0]
      in
        ((itctx, rctx, t :: sctx), time)
      end
    | AND => cmp "AND" op%/\? T0
    | OR => cmp "OR" op%\/? T0
    | POP =>
      let
        val (t0, sctx) = assert_cons sctx
      in
        ((itctx, rctx, sctx), time)
      end
    | MLOAD => 
      let
        val (t0, sctx) = assert_cons sctx
        val def () = raise Impossible $ sprintf "MLOAD: can't read from address of type $" [str_t t0]
        val t =
            case t0 of
                TNat i0 =>
                (case simp_i i0 of
                    IConst (ICNat n, _) =>
                    (case is_reg_addr num_regs n of
                         SOME n =>
                         (case rctx @! n of
                              SOME t => t
                            | NONE => raise Impossible $ sprintf "MLOAD: reg$'s type is unknown" [str_int n])
                       | NONE => def ())
                  | _ => def ())
              | TTuplePtr (ts, offset) =>
                (case simp_i offset of
                     IConst (ICNat n, _) =>
                     (case is_tuple_offset (length ts) n of
                          SOME n => List.nth (ts, n)
                        | NONE => raise Impossible $ sprintf "MLOAD: bad offset in type $" [str_t t0])
                   | _ => raise Impossible $ sprintf "MLOAD: unknown offset in type $" [str_t t0])
              | TArrayPtr (t, len, offset) =>
                let
                  fun read () = (write_prop (offset %mod N32 %= N0 /\ N1 %<= offset %/ N32 /\ offset %/ N32 %<= len); t)
                in
                  case simp_i offset of
                     IConst (ICNat n, _) =>
                     if n = 0 then TNat len
                     else read ()
                   | _ => read ()
                end
      in
        ((itctx, rctx, t :: sctx), T_MLOAD)
      end
    | MSTORE => 
      let
        val (t0, t1, sctx) = assert_cons sctx
        val def () = raise Impossible $ sprintf "MSTORE: can't write to address of type $" [str_t t0]
        val rctx =
            case t0 of
                TNat i0 =>
                let
                in
                  case simp_i i0 of
                      IConst (ICNat n, _) =>
                      (case is_reg_addr num_regs n of
                           SOME n => rctx @+ (n, t1)
                         | NONE => def ())
                    | _ => def ()
                end
              | TArrayPtr (t, len, offset) =>
                (is_eq_ty ictx (t1, t); write_prop (offset %mod N32 %= N0 /\ N1 %<= offset %/ N32 /\ offset %/ N32 %<= len); rctx)
              | _ => def ()
      in
        ((itctx, rctx, sctx), T_STORE)
      end
    | JUMPDEST => (ctx, T0)
    | PUSH (n, w) => (assert_b (1 <= n andalso n <= 32); ((itctx, rctx, tc_w ctx (unInner w) :: sctx), T_PUSH))
    | DUP n => 
      let
        val () = assert_b (1 <= n andalso n <= 16)
        val () = assert_b (length sctx >= n)
      in
        ((itctx, rctx, List.nth (sctx, n-1) :: sctx), T0)
      end
    | SWAP n => 
      let
        val () = assert_b (1 <= n andalso n <= 16)
        val () = assert_b (length sctx >= n+1)
        fun swap n ls =
          let
            val ls1 = take n ls
            val ls2 = drop n ls
            val (a1, ls1) = assert_cons ls1
            val (a2, ls2) = assert_cons ls2
          in
            a2 :: ls1 @ (a1 :: ls2)
          end
      in
        ((itctx, rctx, swap n sctx), T0)
      end
    | VALUE_AppT t =>
      let
        val (t0, sctx) = assert_cons sctx
        val t0 = whnf itctx t0
        val ((_, k), t2) = assert_TForall t0
        val t = kc_agaisnt_kind itctx (unInner t, k)
        val t = subst0_t_t t t2
      in
        ((itctx, rctx, t :: sctx), T0)
      end
    | VALUE_Pack (t_pack, t) =>
      let
        val t_pack = kc_against_kind itctx (unInner t_pack, KType)
        val t_pack = whnf itctx t_pack
        val ((_, k), t') = assert_TExists t_pack
        val t = kc_against_kind itctx (unInner t, k)
        val t_v = subst0_t_t t t'
        val (t0, sctx) = assert_cons sctx
        val () = is_eq_ty itctx (t0, t_v)
      in
        ((itctx, rctx, t_pack :: sctx), T0)
      end
    | VALUE_Fold t_fold =>
      let
        val t_fold = kc_against_kind itctx (unInner t_fold, KType)
        val t_fold = whnf itctx t_fold
        val (t, args) = collect_TAppIT t_fold
        val ((_, k), t1) = assert_TRec t
        val t = TAppITs (subst0_t_t t t1) args
        val (t0, sctx) = assert_cons sctx
        val () = is_eq_ty itctx (t0, t)
      in
        ((itctx, rctx, t_fold :: sctx), T0)
      end
    | VALUE_AscType t =>
      let
        val t = kc_against_kind itctx (unInner t, KType)
        val (t0, sctx) = assert_cons sctx
        val () = is_eq_ty itctx (t0, t)
      in
        ((itctx, rctx, t :: sctx), T0)
      end
    | UNPACK name =>
      let
        val (t0, sctx) = assert_cons sctx
        val t0 = whnf itctx t0
        val ((_, k), t) = assert_TExists t0
      in
        (add_stack t $ add_kinding_full (binder2str name, k) (itctx, rctx, sctx), T0)
      end
    | UNFOLD =>
      let
        val (t0, sctx) = assert_cons sctx
        val t0 = whnf itctx t0
        val (t, args) = collect_TAppIT t0
        val ((_, k), t1) = assert_TRec t
        val t = TAppITs (subst0_t_t t t1) args
      in
        ((itctx, rctx, t :: sctx), T0)
      end
    | NAT2INT =>
      let
        val (t0, sctx) = assert_cons sctx
        val _ = assert_TNat t0
      in
        ((itctx, rctx, TInt :: sctx), T0)
      end
    | INT2NAT =>
      let
        val (t0, sctx) = assert_cons sctx
        val _ = assert_TInt t0
      in
        ((itctx, rctx, TSomeNat () :: sctx), T0)
      end
    | BYTE2INT =>
      let
        val (t0, sctx) = assert_cons sctx
        val _ = assert_TByte t0
      in
        ((itctx, rctx, TInt :: sctx), T0)
      end
    (* | PRINTC => *)
    (*   let *)
    (*     val (t0, sctx) = assert_cons sctx *)
    (*     val _ = assert_TByte t0 *)
    (*   in *)
    (*     ((itctx, rctx, TUnit :: sctx), T0) *)
    (*   end *)
    | _ => raise Impossible $ "unknown case in tc_inst(): " ^ (EVM1ExportPP.pp_insts_to_string $ EVM1ExportPP.export_insts (NONE, NONE) (itctx_names itctx) insts)
  end
      
fun tc_insts (ctx as (hctx, itctx as (ictx, tctx), rctx)) insts =
  let
    fun main () =
  case insts of
      JUMP v =>
      let
        val (t0, sctx) = assert_cons sctx
        val t0 = whnf itctx t0
        val (rctx', sctx', i) = assert_TArrowEVM t0
        val () = is_sub_rctx itctx (rctx, rctx')
        val () = is_eq_tys itctx (sctx, sctx')
      in
        T_JUMP %+ i
      end
    (* | ISHalt t => *)
    (*   let *)
    (*     val t = kc_against_kind itctx (t, KType) *)
    (*     val () = tc_v_against_ty ctx (VReg 1, t) *)
    (*   in *)
    (*     T1 *)
    (*   end *)
    | ISDummy _ => T0
    | ISCons bind =>
      let
        val (inst, I) = unBind bind
      in
        case inst of
            JUMPI =>
            let
              val (t0, t1, sctx) = assert_cons2 sctx
              val () = assert_TBool t1
              val t0 = whnf itctx t0
              val (rctx', sctx', i2) = assert_TArrowEVM t0
              val () = is_sub_rctx itctx (rctx, rctx')
              val () = is_eq_tys itctx (sctx, sctx')
              val i1 = tc_insts ctx I
            in
              T_JUMPI %+ IMax (i1, i2)
            end
          | IAscTime i =>
            let
              val i = sc_against_sort ictx (unInner i, STime)
              val i' = tc_insts ctx I
              val () = check_prop ictx (i' %<= i)
            in
              i
            end
          | _ =>
            let
              val (ctx, i1) = tc_inst params ctx inst 
              val i2 = tc_insts ctx I
            in
              i1 %+ i2
            end
      end
    fun extra_msg () = "\nwhen typechecking\n" ^ (EVM1ExportPP.pp_insts_to_string $ EVM1ExportPP.export_insts (SOME 2, SOME 5) (itctx_names itctx) insts)
    val ret = main ()
              handle
              Impossible m => raise Impossible (m ^ extra_msg ())
              | MUnifyError (r, m) => raise MTCError ("Unification error:\n" ^ join_lines m ^ extra_msg ())
              (* | ForgetError (r, m) => raise MTCError ("Forgetting error: " ^ m ^ extra_msg ()) *)
              (* | MSCError (r, m) => raise MTCError ("Sortcheck error:\n" ^ join_lines m ^ extra_msg ()) *)
              (* | MTCError m => raise MTCError (m ^ extra_msg ()) *)
  in
    ret
  end

fun tc_hval params (hctx, num_regs) h =
  let
    val () = println "tc_hval() started"
    val (itbinds, ((rctx, sctx, i), insts)) = unBind h
    val itbinds = unTeles itbinds
    val () = println "before getting itctx"
    val itctx as (ictx, tctx) =
        foldl
          (fn (bind, (ictx, tctx)) =>
              case bind of
                  inl (name, s) => ((binder2str name, is_wf_sort ictx $ unOuter s) :: ictx, tctx)
                | inr (name, k) => (ictx, (binder2str name, k) :: tctx)
          ) ([], []) itbinds
    val () = println "before checking rctx"
    (* val itctxn = itctx_names itctx *)
    val rctx = Rctx.mapi
                 (fn (r, t) =>
                     let
                       (* val () = println $ sprintf "checking r$: $" [str_int r, ExportPP.pp_t_to_string NONE $ ExportPP.export_t NONE itctxn t] *)
                       val ret = kc_against_kind itctx (t, KType)
                       (* val () = println "done" *)
                     in
                       ret
                     end) rctx
    val () = println "before checking sctx"
    val sctx = map (kc_against_KType itctx) sctx
    val () = println "before checking i"
    val i = sc_against_sort ictx (i, STime)
    val () = println "before checking insts"
    val i' = tc_insts params (itctx, rctx, sctx) insts
    val () = println "after checking insts"
    val () = check_prop ictx (i' %<= i)
    val () = println "tc_hval() finished"
  in
    ()
  end

fun tc_prog num_regs (H, I) =
  let
    fun get_hval_type h =
      let
        val (itbinds, ((rctx, sctx, i), _)) = unBind h
        val itbinds = unTeles itbinds
        val itbinds = map (map_inl_inr (mapPair' unBinderName unOuter) (mapFst unBinderName)) itbinds
        val t = TForallITs (itbinds, TArrowEVM (rctx, sctx, i))
      in
        t
      end
    fun get_hctx H = RctxUtil.fromList $ map (mapPair' fst get_hval_type) H
    val hctx = get_hctx H
    val () = app (fn ((l, name), h) => (println $ sprintf "tc_hval() on: $ <$>" [str_int l, name]; tc_hval hctx h)) H
    val i = tc_insts (hctx, num_regs) (([], []), Rctx.empty, []) I
  in
    i
  end
    
fun evm1_typecheck num_regs P =
  let
    val ret = runWriter (fn () => tc_prog num_regs P) ()
  in
    ret
  end

end