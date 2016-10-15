structure Passes =
struct
  open MicroTiML
  open Util

  structure TermShift =
  struct
    structure TermShiftHelper =
    struct
      type down = int * int
      type up = unit

      val upward_base = ()
      fun combiner ((), ()) = ()

      fun transformer_constr (transform_constr, transform_kind) (cstr : constr, (ctx, delta) : down) =
        case cstr of
          CstrVar a => SOME (CstrVar (if a >= ctx then a + delta else a), ())
        | CstrTimeAbs cstr1 =>
            let
              val (cstr1, ()) = transform_constr (cstr1, (ctx + 1, delta))
            in
              SOME (CstrTimeAbs cstr1, ())
            end
        | CstrAbs (kd1, cstr2) =>
            let
              val (kd1, ()) = transform_kind (kd1, (ctx, delta))
              val (cstr2, ()) = transform_constr (cstr2, (ctx + 1, delta))
            in
              SOME (CstrAbs (kd1, cstr2), ())
            end
        | CstrForall (kd1, cstr2) =>
            let
              val (kd1, ()) = transform_kind (kd1, (ctx, delta))
              val (cstr2, ()) = transform_constr (cstr2, (ctx + 1, delta))
            in
              SOME (CstrForall (kd1, cstr2), ())
            end
        | CstrExists (kd1, cstr2) =>
            let
              val (kd1, ()) = transform_kind (kd1, (ctx, delta))
              val (cstr2, ()) = transform_constr (cstr2, (ctx + 1, delta))
            in
              SOME (CstrExists (kd1, cstr2), ())
            end
        | CstrRec (kd1, cstr2) =>
            let
              val (kd1, ()) = transform_kind (kd1, (ctx, delta))
              val (cstr2, ()) = transform_constr (cstr2, (ctx + 1, delta))
            in
              SOME (CstrRec (kd1, cstr2), ())
            end
        | _ => NONE

      fun transformer_kind (transform_kind, transform_prop) (kd : kind, (ctx, delta) : down) =
        case kd of
          KdSubset (kd1, pr2) =>
            let
              val (kd1, ()) = transform_kind (kd1, (ctx, delta))
              val (pr2, ()) = transform_prop (pr2, (ctx + 1, delta))
            in
              SOME (KdSubset (kd1, pr2), ())
            end
        | _ => NONE

      fun transformer_prop (transform_constr, transform_kind, transform_prop) (pr : prop, (ctx, delta) : down) =
        case pr of
          PrForall (kd1, pr2) =>
            let
              val (kd1, ()) = transform_kind (kd1, (ctx, delta))
              val (pr2, ()) = transform_prop (pr2, (ctx + 1, delta))
            in
              SOME (PrForall (kd1, pr2), ())
            end
        | PrExists (kd1, pr2) =>
            let
              val (kd1, ()) = transform_kind (kd1, (ctx, delta))
              val (pr2, ()) = transform_prop (pr2, (ctx + 1, delta))
            in
              SOME (PrExists (kd1, pr2), ())
            end
        | _ => NONE

      fun transformer_term (transform_constr, transform_kind, transform_term) (tm : term, (ctx, delta) : down) =
        case tm of
          TmVar x => SOME (TmVar (if x >= ctx then x + delta else x), ())
        | TmAbs (cstr1, tm2) =>
            let
              val (cstr1, ()) = transform_constr (cstr1, (ctx, delta))
              val (tm2, ()) = transform_term (tm2, (ctx + 1, delta))
            in
              SOME (TmAbs (cstr1, tm2), ())
            end
        | TmRec (cstr1, tm2) =>
            let
              val (cstr1, ()) = transform_constr (cstr1, (ctx, delta))
              val (tm2, ()) = transform_term (tm2, (ctx + 1, delta))
            in
              SOME (TmRec (cstr1, tm2), ())
            end
        | TmCase (tm1, tm2, tm3) =>
            let
              val (tm1, ()) = transform_term (tm1, (ctx, delta))
              val (tm2, ()) = transform_term (tm2, (ctx + 1, delta))
              val (tm3, ()) = transform_term (tm3, (ctx + 1, delta))
            in
              SOME (TmCase (tm1, tm2, tm3), ())
            end
        | TmUnpack (tm1, tm2) =>
            let
              val (tm1, ()) = transform_term (tm1, (ctx, delta))
              val (tm2, ()) = transform_term (tm2, (ctx + 2, delta))
            in
              SOME (TmUnpack (tm1, tm2), ())
            end
        | TmCstrAbs (kd1, tm2) =>
            let
              val (kd1, ()) = transform_kind (kd1, (ctx, delta))
              val (tm2, ()) = transform_term (tm2, (ctx + 1, delta))
            in
              SOME (TmCstrAbs (kd1, tm2), ())
            end
        | TmLet (tm1, tm2) =>
            let
              val (tm1, ()) = transform_term (tm1, (ctx, delta))
              val (tm2, ()) = transform_term (tm2, (ctx + 1, delta))
            in
              SOME (TmLet (tm1, tm2), ())
            end
        | _ => NONE
    end

    structure TermShiftIns = TermTransformPass(TermShiftHelper)
    open TermShiftIns

    fun shift_constr_above d c cstr = #1 (transform_constr (cstr, (c, d)))
    fun shift_constr d cstr = shift_constr_above d 0 cstr

    fun shift_kind_above d c kd = #1 (transform_kind (kd, (c, d)))
    fun shift_kind d kd = shift_kind_above d 0 kd

    fun shift_prop_above d c pr = #1 (transform_prop (pr, (c, d)))
    fun shift_prop d pr = shift_prop_above d 0 pr

    fun shift_term_above d c tm = #1 (transform_term (tm, (c, d)))
    fun shift_term d tm = shift_term_above d 0 tm
  end

  structure TermSubstConstr =
  struct
    structure TermSubstConstrHelper =
    struct
      type down = int * constr
      type up = unit

      val upward_base = ()
      fun combiner ((), ()) = ()

      fun transformer_constr (on_constr, on_kind) (cstr : constr, down as (who, to) : down) =
        case cstr of
          CstrVar a => SOME (if a = who then TermShift.shift_constr who to else cstr, ())
        | CstrTimeAbs cstr1 =>
            let
              val (cstr1, ()) = on_constr (cstr1, (who + 1, to))
            in
              SOME (CstrTimeAbs cstr1, ())
            end
        | CstrAbs (kd1, cstr2) =>
            let
              val (kd1, ()) = on_kind (kd1, down)
              val (cstr2, ()) = on_constr (cstr2, (who + 1, to))
            in
              SOME (CstrAbs (kd1, cstr2), ())
            end
        | CstrForall (kd1, cstr2) =>
            let
              val (kd1, ()) = on_kind (kd1, down)
              val (cstr2, ()) = on_constr (cstr2, (who + 1, to))
            in
              SOME (CstrForall (kd1, cstr2), ())
            end
        | CstrExists (kd1, cstr2) =>
            let
              val (kd1, ()) = on_kind (kd1, down)
              val (cstr2, ()) = on_constr (cstr2, (who + 1, to))
            in
              SOME (CstrExists (kd1, cstr2), ())
            end
        | CstrRec (kd1, cstr2) =>
            let
              val (kd1, ()) = on_kind (kd1, down)
              val (cstr2, ()) = on_constr (cstr2, (who + 1, to))
            in
              SOME (CstrRec (kd1, cstr2), ())
            end
        | _ => NONE

      fun transformer_kind (on_kind, on_prop) (kd : kind, down as (who, to) : down) =
        case kd of
          KdSubset (kd1, pr2) =>
            let
              val (kd1, ()) = on_kind (kd1, down)
              val (pr2, ()) = on_prop (pr2, (who + 1, to))
            in
              SOME (KdSubset (kd1, pr2), ())
            end
        | _ => NONE

      fun transformer_prop (on_constr, on_kind, on_prop) (pr : prop, down as (who, to) : down) =
        case pr of
          PrForall (kd1, pr2) =>
            let
              val (kd1, ()) = on_kind (kd1, down)
              val (pr2, ()) = on_prop (pr2, (who + 1, to))
            in
              SOME (PrForall (kd1, pr2), ())
            end
        | PrExists (kd1, pr2) =>
            let
              val (kd1, ()) = on_kind (kd1, down)
              val (pr2, ()) = on_prop (pr2, (who + 1, to))
            in
              SOME (PrExists (kd1, pr2), ())
            end
        | _ => NONE

      fun transformer_term (on_constr, on_kind, on_term) (tm : term, down as (who, to) : down) =
        case tm of
          TmAbs (cstr1, tm2) =>
            let
              val (cstr1, ()) = on_constr (cstr1, down)
              val (tm2, ()) = on_term (tm2, (who + 1, to))
            in
              SOME (TmAbs (cstr1, tm2), ())
            end
        | TmRec (cstr1, tm2) =>
            let
              val (cstr1, ()) = on_constr (cstr1, down)
              val (tm2, ()) = on_term (tm2, (who + 1, to))
            in
              SOME (TmRec (cstr1, tm2), ())
            end
        | TmCase (tm1, tm2, tm3) =>
           let
             val (tm1, ()) = on_term (tm1, down)
             val (tm2, ()) = on_term (tm2, (who + 1, to))
             val (tm3, ()) = on_term (tm3, (who + 1, to))
           in
             SOME (TmCase (tm1, tm2, tm3), ())
           end
        | TmUnpack (tm1, tm2) =>
            let
              val (tm1, ()) = on_term (tm1, down)
              val (tm2, ()) = on_term (tm2, (who + 2, to))
            in
              SOME (TmUnpack (tm1, tm2), ())
            end
        | TmCstrAbs (kd1, tm2) =>
            let
              val (kd1, ()) = on_kind (kd1, down)
              val (tm2, ()) = on_term (tm2, (who + 1, to))
            in
              SOME (TmCstrAbs (kd1, tm2), ())
            end
        | TmLet (tm1, tm2) =>
            let
              val (tm1, ()) = on_term (tm1, down)
              val (tm2, ()) = on_term (tm2, (who + 1, to))
            in
              SOME (TmLet (tm1, tm2), ())
            end
        | _ => NONE
    end

    structure TermSubstConstrIns = TermTransformPass(TermSubstConstrHelper)
    open TermSubstConstrIns

    fun subst_constr_in_term_top to tm =
      TermShift.shift_term ~1 (#1 (transform_term (tm, (0, TermShift.shift_constr 1 to))))

    fun subst_constr_in_constr_top to cstr =
      TermShift.shift_constr ~1 (#1 (transform_constr (cstr, (0, TermShift.shift_constr 1 to))))
  end

  structure TermSubstTerm =
  struct
    structure TermSubstTermHelper =
    struct
      type down = int * term
      type up = unit

      val upward_base = ()
      fun combiner ((), ()) = ()

      fun transformer_constr (on_constr, on_kind) (cstr : constr, down as (who, to) : down) = NONE

      fun transformer_kind (on_kind, on_prop) (kd : kind, down as (who, to) : down) = NONE

      fun transformer_prop (on_constr, on_kind, on_prop) (pr : prop, down as (who, to) : down) = NONE

      fun transformer_term (on_constr, on_kind, on_term) (tm : term, down as (who, to) : down) =
        case tm of
          TmVar x => SOME (if x = who then TermShift.shift_term who to else tm, ())
        | TmAbs (cstr1, tm2) =>
            let
              val (cstr1, ()) = on_constr (cstr1, down)
              val (tm2, ()) = on_term (tm2, (who + 1, to))
            in
              SOME (TmAbs (cstr1, tm2), ())
            end
        | TmRec (cstr1, tm2) =>
            let
              val (cstr1, ()) = on_constr (cstr1, down)
              val (tm2, ()) = on_term (tm2, (who + 1, to))
            in
              SOME (TmRec (cstr1, tm2), ())
            end
        | TmCase (tm1, tm2, tm3) =>
           let
             val (tm1, ()) = on_term (tm1, down)
             val (tm2, ()) = on_term (tm2, (who + 1, to))
             val (tm3, ()) = on_term (tm3, (who + 1, to))
           in
             SOME (TmCase (tm1, tm2, tm3), ())
           end
        | TmUnpack (tm1, tm2) =>
            let
              val (tm1, ()) = on_term (tm1, down)
              val (tm2, ()) = on_term (tm2, (who + 2, to))
            in
              SOME (TmUnpack (tm1, tm2), ())
            end
        | TmCstrAbs (kd1, tm2) =>
            let
              val (kd1, ()) = on_kind (kd1, down)
              val (tm2, ()) = on_term (tm2, (who + 1, to))
            in
              SOME (TmCstrAbs (kd1, tm2), ())
            end
        | TmLet (tm1, tm2) =>
            let
              val (tm1, ()) = on_term (tm1, down)
              val (tm2, ()) = on_term (tm2, (who + 1, to))
            in
              SOME (TmLet (tm1, tm2), ())
            end
        | _ => NONE
    end

    structure TermSubstTermIns = TermTransformPass(TermSubstTermHelper)
    open TermSubstTermIns

    fun subst_term_in_term_top to tm =
      TermShift.shift_term ~1 (#1 (transform_term (tm, (0, TermShift.shift_term 1 to))))
  end

  structure Printer =
  struct
    structure PrinterHelper =
    struct
      type down = string list
      type up = string

      val upward_base = ""
      fun combiner (_, _) = ""

      val gensym =
        let
          val counter = ref 0
        in
          fn () =>
            let
              val res = "%var" ^ (str_int (!counter))
              val _ = inc counter
            in
              res
            end
        end

      fun transformer_constr (transform_constr, transform_kind) (cstr : constr, ctx : down) =
        let
          val str_constr = snd o transform_constr
          val str_kind = snd o transform_kind
          val res =
            case cstr of
              CstrVar a => List.nth (ctx, a)
            | CstrNat n => str_int n
            | CstrTime t => t
            | CstrUnit => "()"
            | CstrTrue => "true"
            | CstrFalse => "false"
            | CstrUnOp (uop, cstr1) => "(" ^ str_constr_un_op uop ^ " " ^ str_constr (cstr1, ctx) ^ ")"
            | CstrBinOp (bop, cstr1, cstr2) => "(" ^ str_constr_bin_op bop ^ " " ^ str_constr (cstr1, ctx) ^ " " ^ str_constr (cstr2, ctx) ^ ")"
            | CstrIte (cstr1, cstr2, cstr3) => "(if " ^ str_constr (cstr1, ctx) ^ " " ^ str_constr (cstr2, ctx) ^ " " ^ str_constr (cstr3, ctx) ^ ")"
            | CstrTimeAbs cstr1 =>
                let
                  val fresh = gensym ()
                in
                  "(TimeLambda (" ^ fresh ^ ") " ^ str_constr (cstr1, fresh :: ctx) ^ ")"
                end
            | CstrProd (cstr1, cstr2) => "(Pair " ^ str_constr (cstr1, ctx) ^ " " ^ str_constr (cstr2, ctx) ^ ")"
            | CstrSum (cstr1, cstr2) => "(Sum " ^ str_constr (cstr1, ctx) ^ " " ^ str_constr (cstr2, ctx) ^ ")"
            | CstrArrow (cstr1, cstr2, cstr3) => "(-> " ^ str_constr (cstr1, ctx) ^ " " ^ str_constr (cstr2, ctx) ^ " with " ^ str_constr (cstr3, ctx) ^ ")"
            | CstrApp (cstr1, cstr2) => "[" ^ str_constr (cstr1, ctx) ^ " " ^ str_constr (cstr2, ctx) ^ "]"
            | CstrAbs (kd1, cstr2) =>
                let
                  val fresh = gensym ()
                in
                  "(CstrLambda (" ^ fresh ^ " : " ^ str_kind (kd1, ctx) ^ ") " ^ str_constr (cstr2, fresh :: ctx) ^ ")"
                end
            | CstrForall (kd1, cstr2) =>
                let
                  val fresh = gensym ()
                in
                  "(Forall (" ^ fresh ^ " : " ^ str_kind (kd1, ctx) ^ ") " ^ str_constr (cstr2, fresh :: ctx) ^ ")"
                end
            | CstrExists (kd1, cstr2) =>
                let
                  val fresh = gensym ()
                in
                  "(Exists (" ^ fresh ^ " : " ^ str_kind (kd1, ctx) ^ ") " ^ str_constr (cstr2, fresh :: ctx) ^ ")"
                end
            | CstrRec (kd1, cstr2) =>
                let
                  val fresh = gensym ()
                in
                  "(Rec (" ^ fresh ^ " : " ^ str_kind (kd1, ctx) ^ ") " ^ str_constr (cstr2, fresh :: ctx) ^ ")"
                end
            | CstrTypeUnit => "unit"
            | CstrTypeInt => "int"
            | CstrTypeNat cstr1 => "nat(" ^ str_constr (cstr1, ctx) ^ ")"
            | CstrTypeArray (cstr1, cstr2) => "array(" ^ str_constr (cstr1, ctx) ^ ", " ^ str_constr (cstr2, ctx) ^ ")"
        in
          SOME (cstr, res)
        end

      fun transformer_kind (transform_kind, transform_prop) (kd : kind, ctx : down) =
        let
          val str_kind = snd o transform_kind
          val str_prop = snd o transform_prop
          val res =
            case kd of
              KdNat => "Nat"
            | KdUnit => "Unit"
            | KdBool => "Bool"
            | KdTimeFun n => "TimeFun(" ^ str_int n ^ ")"
            | KdSubset (kd1, pr2) =>
                let
                  val fresh = gensym ()
                in
                  "{ " ^ fresh ^ " : " ^ str_kind (kd1, ctx) ^ " | " ^ str_prop (pr2, fresh :: ctx) ^ "}"
                end
            | KdProper => "*"
            | KdArrow (kd1, kd2) => "(=> " ^ str_kind (kd1, ctx) ^ " " ^ str_kind (kd2, ctx) ^ ")"
        in
          SOME (kd, res)
        end

      fun transformer_prop (transform_constr, transform_kind, transform_prop) (pr : prop, ctx : down) =
        let
          val str_constr = snd o transform_constr
          val str_kind = snd o transform_kind
          val str_prop = snd o transform_prop
          val res =
            case pr of
              PrTop => "top"
            | PrBot => "bot"
            | PrBinConn (conn, pr1, pr2) => "(" ^ str_prop_bin_conn conn ^ " " ^ str_prop (pr1, ctx) ^ " " ^ str_prop (pr2, ctx) ^ ")"
            | PrNot pr1 => "(not " ^ str_prop (pr1, ctx) ^ ")"
            | PrBinRel (rel, cstr1, cstr2) => "(" ^ str_prop_bin_rel rel ^ " " ^ str_constr (cstr1, ctx) ^ " " ^ str_constr (cstr2, ctx) ^ ")"
            | PrForall (kd1, pr2) =>
                let
                  val fresh = gensym ()
                in
                  "(forall (" ^ fresh ^ " : " ^ str_kind (kd1, ctx) ^ ") " ^ str_prop (pr2, fresh :: ctx) ^ ")"
                end
            | PrExists (kd1, pr2) =>
                let
                  val fresh = gensym ()
                in
                  "(exists (" ^ fresh ^ " : " ^ str_kind (kd1, ctx) ^ ") " ^ str_prop (pr2, fresh :: ctx) ^ ")"
                end
        in
          SOME (pr, res)
        end

      fun transformer_term (transform_constr, transform_kind, transform_term) (tm : term, ctx : down) =
        SOME (tm, Option.valOf (case tm of
          TmVar x => SOME (List.nth (ctx, x))
        | TmInt i => SOME (str_int i)
        | TmNat n => SOME ("#" ^ str_int n)
        | TmUnit => SOME "()"
        | TmApp (tm1, tm2) => SOME ("(" ^ snd (transform_term (tm1, ctx)) ^ " " ^ snd (transform_term (tm2, ctx)) ^ ")")
        | TmAbs (cstr1, tm2) =>
            let
              val fresh = gensym ()
            in
              SOME ("(lambda (" ^ fresh ^ " : " ^ snd (transform_constr (cstr1, ctx)) ^ ") " ^ snd (transform_term (tm2, fresh :: ctx)) ^ ")")
            end
        | TmRec (cstr1, tm2) =>
            let
              val fresh = gensym()
            in
                SOME ("(fix (" ^ fresh ^ " : " ^ snd (transform_constr (cstr1, ctx)) ^ ") " ^ snd (transform_term (tm2, fresh :: ctx)) ^ ")")
            end
        | TmPair (tm1, tm2) => SOME ("(cons " ^ snd (transform_term (tm1, ctx)) ^ " " ^ snd (transform_term (tm2, ctx)) ^ ")")
        | TmFst tm1 => SOME ("(fst " ^ snd (transform_term (tm1, ctx)) ^ ")")
        | TmSnd tm2 => SOME ("(snd " ^ snd (transform_term (tm2, ctx)) ^ ")")
        | TmInLeft tm1 => SOME ("(inl " ^ snd (transform_term (tm1, ctx)) ^ ")")
        | TmInRight tm1 => SOME ("(inr " ^ snd (transform_term (tm1, ctx)) ^ ")")
        | TmCase (tm1, tm2, tm3) =>
            let
              val fresh = gensym ()
            in
              SOME ("(case " ^ snd (transform_term (tm1, ctx)) ^ " via " ^ fresh ^ " " ^ snd (transform_term (tm2, fresh :: ctx)) ^ " " ^ snd (transform_term (tm3, fresh :: ctx)) ^ ")")
            end
        | TmFold tm1 => SOME ("(fold " ^ snd (transform_term (tm1, ctx)) ^ ")")
        | TmUnfold tm1 => SOME ("(unfold " ^ snd (transform_term (tm1, ctx)) ^ ")")
        | TmPack (cstr1, tm2) => SOME ("<" ^ snd (transform_constr (cstr1, ctx)) ^ " | " ^ snd (transform_term (tm2, ctx)) ^ ">")
        | TmUnpack (tm1, tm2) =>
            let
              val fresh1 = gensym ()
              val fresh2 = gensym ()
            in
              SOME ("(unpack " ^ snd (transform_term (tm1, ctx)) ^ " via <" ^ fresh1 ^ " | " ^ fresh2 ^ "> " ^ snd (transform_term (tm2, fresh2 :: fresh1 :: ctx)) ^ ")")
            end
        | TmCstrAbs (kd1, tm2) =>
            let
              val fresh = gensym ()
            in
                SOME ("(Lambda (" ^ fresh ^ " : " ^ snd (transform_kind (kd1, ctx)) ^ ") " ^ snd (transform_term (tm2, fresh :: ctx)) ^ ")")
            end
        | TmCstrApp (tm1, cstr2) => SOME ("[" ^ snd (transform_term (tm1, ctx)) ^ " " ^ snd (transform_constr (cstr2, ctx)) ^ "]")
        | TmBinOp (bop, tm1, tm2) => SOME ("(" ^ str_term_bin_op bop ^ " " ^ snd (transform_term (tm1, ctx)) ^ " " ^ snd (transform_term (tm2, ctx)) ^ ")")
        | TmArrayNew (tm1, tm2) => SOME ("(newarray " ^ snd (transform_term (tm1, ctx)) ^ " " ^ snd (transform_term (tm2, ctx)) ^ ")")
        | TmArrayGet (tm1, tm2) => SOME ("(getarray " ^ snd (transform_term (tm1, ctx)) ^ " " ^ snd (transform_term (tm2, ctx)) ^ ")")
        | TmArrayPut (tm1, tm2, tm3) => SOME ("(putarray " ^ snd (transform_term (tm1, ctx)) ^ " " ^ snd (transform_term (tm2, ctx)) ^ " " ^ snd (transform_term (tm3, ctx)) ^ ")")
        | TmLet (tm1, tm2) =>
            let
              val fresh = gensym ()
            in
              SOME ("(let ([" ^ fresh ^ " " ^ snd (transform_term (tm1, ctx)) ^ "]) " ^ snd (transform_term (tm2, fresh :: ctx)) ^ ")")
            end
        | TmNever => SOME "never"
        | TmFixAbs (kinds, cstr1, tm2) =>
            let
              val fresh1 = gensym ()
              val fresh2 = gensym ()
              val freshes = map (fn _ => gensym ()) kinds
            in
              SOME ("(fix " ^ fresh1 ^ "[" ^ str_int (List.length freshes) ^ "](" ^ fresh2 ^ ")" ^ ":" ^ snd (transform_constr (cstr1, freshes @ ctx)) ^ " " ^ snd (transform_term (tm2, fresh2 :: fresh1 :: (freshes @ ctx))) ^ ")")
            end))
    end

    structure PrinterIns = TermTransformPass(PrinterHelper)
    open PrinterIns

    fun str_constr cstr = snd (transform_constr (cstr, []))
    fun str_term tm = snd (transform_term (tm, []))
  end

  structure ANF =
  struct
    fun normalize_term tm = normalize tm (fn (x, d) => x)

    and normalize tm k =
      case tm of
        TmVar _ => k (tm, 0)
      | TmInt _ => k (tm, 0)
      | TmNat _ => k (tm, 0)
      | TmUnit => k (tm, 0)
      | TmApp (tm1, tm2) =>
          normalize_shift tm1 (fn (tm1, d1) =>
            normalize_shift (TermShift.shift_term_above d1 0 tm2) (fn (tm2, d2) =>
              k (TmApp (TermShift.shift_term_above d2 0 tm1, tm2), d1 + d2)))
      | TmAbs (cstr1, tm2) => k (TmAbs (cstr1, normalize_term tm2), 0)
      | TmRec (cstr1, tm2) => k (TmRec (cstr1, normalize_term tm2), 0)
      | TmPair (tm1, tm2) =>
          normalize_shift tm1 (fn (tm1, d1) =>
            normalize_shift (TermShift.shift_term_above d1 0 tm2) (fn (tm2, d2) =>
              k (TmPair (TermShift.shift_term_above d2 0 tm1, tm2), d1 + d2)))
      | TmFst tm1 => normalize_shift tm1 (fn (tm1, d1) => k (TmFst tm1, d1))
      | TmSnd tm1 => normalize_shift tm1 (fn (tm1, d1) => k (TmSnd tm1, d1))
      | TmInLeft tm1 => normalize_shift tm1 (fn (tm1, d1) => k (TmInLeft tm1, d1))
      | TmInRight tm1 => normalize_shift tm1 (fn (tm1, d1) => k (TmInRight tm1, d1))
      | TmCase (tm1, tm2, tm3) =>
          normalize_shift tm1 (fn (tm1, d1) =>
            k (TmCase (tm1, normalize_term (TermShift.shift_term_above d1 1 tm2), normalize_term (TermShift.shift_term_above d1 1 tm3)), d1))
      | TmFold tm1 => normalize_shift tm1 (fn (tm1, d1) => k (TmFold tm1, d1))
      | TmUnfold tm1 => normalize_shift tm1 (fn (tm1, d1) => k (TmUnfold tm1, d1))
      | TmPack (cstr1, tm2) => normalize_shift tm2 (fn (tm2, d2) => k (TmPack (TermShift.shift_constr_above d2 0 cstr1, tm2), d2))
      | TmUnpack (tm1, tm2) =>
          normalize tm1 (fn (tm1, d1) =>
            TmUnpack (tm1, normalize (TermShift.shift_term_above d1 2 tm2) (fn (tm2, d2) =>
              k (tm2, d1 + 2 + d2))))
      | TmCstrAbs (kd1, tm2) => k (TmCstrAbs (kd1, normalize_term tm2), 0)
      | TmCstrApp (tm1, cstr2) => normalize_shift tm1 (fn (tm1, d1) => k (TmCstrApp (tm1, TermShift.shift_constr_above d1 0 cstr2), d1))
      | TmBinOp (bop, tm1, tm2) =>
          normalize_shift tm1 (fn (tm1, d1) =>
            normalize_shift (TermShift.shift_term_above d1 0 tm2) (fn (tm2, d2) =>
              k (TmBinOp (bop, TermShift.shift_term_above d2 0 tm1, tm2), d1 + d2)))
      | TmArrayNew (tm1, tm2) =>
          normalize_shift tm1 (fn (tm1, d1) =>
            normalize_shift (TermShift.shift_term_above d1 0 tm2) (fn (tm2, d2) =>
              k (TmArrayNew (TermShift.shift_term_above d2 0 tm1, tm2), d1 + d2)))
      | TmArrayGet (tm1, tm2) =>
          normalize_shift tm1 (fn (tm1, d1) =>
            normalize_shift (TermShift.shift_term_above d1 0 tm2) (fn (tm2, d2) =>
              k (TmArrayGet (TermShift.shift_term_above d2 0 tm1, tm2), d1 + d2)))
      | TmArrayPut (tm1, tm2, tm3) =>
          normalize_shift tm1 (fn (tm1, d1) =>
            normalize_shift (TermShift.shift_term_above d1 0 tm2) (fn (tm2, d2) =>
              normalize_shift (TermShift.shift_term_above (d1 + d2) 0 tm3) (fn (tm3, d3) =>
                TmLet (TmArrayPut (TermShift.shift_term_above (d2 + d3) 0 tm1, TermShift.shift_term_above d3 0 tm2, tm3), k (TmUnit, d1 + d2 + d3 + 1)))))
      | TmLet (tm1, tm2) =>
          normalize tm1 (fn (tm1, d1) =>
            TmLet (tm1, normalize (TermShift.shift_term_above d1 1 tm2) (fn (tm2, d2) =>
              k (tm2, d1 + 1 + d2))))
      | TmNever => k (tm, 0)
      | TmFixAbs (kinds, cstr1, tm2) => k (TmFixAbs (kinds, cstr1, normalize_term tm2), 0)

    and normalize_shift tm k =
      normalize tm (fn (tm, d) => if is_value tm then k (tm, d) else TmLet (tm, k (TmVar 0, d + 1)))
  end

  structure FV =
  struct
    structure FVHelper =
    struct
      type down = int
      type up = int list * int list

      val upward_base = ([], [])
      fun merge s1 s2 = s1 @ (List.filter (fn x => List.all (fn (y : int) => x <> y) s1) s2)
      fun combiner ((ftv1, fcv1), (ftv2, fcv2)) = (merge ftv1 ftv2, merge fcv1 fcv2)

      fun transformer_constr (transform_constr, transform_kind) (cstr : constr, ctx : down) =
        case cstr of
          CstrVar a => SOME (if a >= ctx then (cstr, ([], [a - ctx])) else (cstr, ([], [])))
        | CstrTimeAbs cstr1 =>
            let
              val (cstr1, up1) = transform_constr (cstr1, ctx + 1)
            in
              SOME (CstrTimeAbs cstr1, up1)
            end
        | CstrAbs (kd1, cstr2) =>
            let
              val (kd1, up1) = transform_kind (kd1, ctx)
              val (cstr2, up2) = transform_constr (cstr2, ctx + 1)
            in
              SOME (CstrAbs (kd1, cstr2), combiner (up1, up2))
            end
        | CstrForall (kd1, cstr2) =>
            let
              val (kd1, up1) = transform_kind (kd1, ctx)
              val (cstr2, up2) = transform_constr (cstr2, ctx + 1)
            in
              SOME (CstrForall (kd1, cstr2), combiner (up1, up2))
            end
        | CstrExists (kd1, cstr2) =>
            let
              val (kd1, up1) = transform_kind (kd1, ctx)
              val (cstr2, up2) = transform_constr (cstr2, ctx + 1)
            in
              SOME (CstrExists (kd1, cstr2), combiner (up1, up2))
            end
        | CstrRec (kd1, cstr2) =>
            let
              val (kd1, up1) = transform_kind (kd1, ctx)
              val (cstr2, up2) = transform_constr (cstr2, ctx + 1)
            in
              SOME (CstrRec (kd1, cstr2), combiner (up1, up2))
            end
        | _ => NONE

      fun transformer_kind (transform_kind, transform_prop) (kd : kind, ctx : down) =
        case kd of
          KdSubset (kd1, pr2) =>
            let
              val (kd1, up1) = transform_kind (kd1, ctx)
              val (pr2, up2) = transform_prop (pr2, ctx + 1)
            in
              SOME (KdSubset (kd1, pr2), combiner (up1, up2))
            end
        | _ => NONE

      fun transformer_prop (transform_constr, transform_kind, transform_prop) (pr : prop, ctx : down) =
        case pr of
          PrForall (kd1, pr2) =>
            let
              val (kd1, up1) = transform_kind (kd1, ctx)
              val (pr2, up2) = transform_prop (pr2, ctx)
            in
              SOME (PrForall (kd1, pr2), combiner (up1, up2))
            end
        | PrExists (kd1, pr2) =>
            let
              val (kd1, up1) = transform_kind (kd1, ctx)
              val (pr2, up2) = transform_prop (pr2, ctx)
            in
              SOME (PrExists (kd1, pr2), combiner (up1, up2))
            end
        | _ => NONE

      fun transformer_term (transform_constr, transform_kind, transform_term) (tm : term, ctx : down) =
        case tm of
          TmVar x => SOME (if x >= ctx then (tm, ([x - ctx], [])) else (tm, ([], [])))
        | TmAbs (cstr1, tm2) =>
            let
              val (cstr1, up1) = transform_constr (cstr1, ctx)
              val (tm2, up2) = transform_term (tm2, ctx + 1)
            in
              SOME (TmAbs (cstr1, tm2), combiner (up1, up2))
            end
        | TmRec (cstr1, tm2) =>
            let
              val (cstr1, up1) = transform_constr (cstr1, ctx)
              val (tm2, up2) = transform_term (tm2, ctx + 1)
            in
              SOME (TmRec (cstr1, tm2), combiner (up1, up2))
            end
        | TmCase (tm1, tm2, tm3) =>
            let
              val (tm1, up1) = transform_term (tm1, ctx)
              val (tm2, up2) = transform_term (tm2, ctx + 1)
              val (tm3, up3) = transform_term (tm3, ctx + 1)
            in
              SOME (TmCase (tm1, tm2, tm3), combiner (combiner (up1, up2), up3))
            end
        | TmUnpack (tm1, tm2) =>
            let
              val (tm1, up1) = transform_term (tm1, ctx)
              val (tm2, up2) = transform_term (tm2, ctx + 2)
            in
              SOME (TmUnpack (tm1, tm2), combiner (up1, up2))
            end
        | TmCstrAbs (kd1, tm2) =>
            let
              val (kd1, up1) = transform_kind (kd1, ctx)
              val (tm2, up2) = transform_term (tm2, ctx + 1)
            in
              SOME (TmCstrAbs (kd1, tm2), combiner (up1, up2))
            end
        | TmLet (tm1, tm2) =>
            let
              val (tm1, up1) = transform_term (tm1, ctx)
              val (tm2, up2) = transform_term (tm2, ctx + 1)
            in
              SOME (TmLet (tm1, tm2), combiner (up1, up2))
            end
        | _ => NONE
    end

    structure FVIns = TermTransformPass(FVHelper)
    open FVIns

    fun free_variables_term tm ctx = #2 (transform_term (tm, ctx))
    fun free_variables_constr cstr ctx = #2 (transform_constr (cstr, ctx))
    fun free_variables_kind kd ctx = #2 (transform_kind (kd, ctx))
    fun free_variables_prop pr ctx = #2 (transform_prop (pr, ctx))
  end
end