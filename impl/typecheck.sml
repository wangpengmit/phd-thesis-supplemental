type var = int

signature THEORY = sig
    type kind
    type constr
    type prop
end

structure Theory : THEORY = struct
type kind = unit
type constr = unit
type prop = unit
end

signature TIME_THEORY = sig
    type kind
    type constr
    val Time : kind
end

functor MakeTimeTheory (structure Theory : THEORY) : TIME_THEORY = struct
	datatype prop =
		 True
		 | False
		 | And of prop * prop
		 | Or of prop * prop
		 | TimeEq of Theory.constr * Theory.constr
		 | Other of Theory.prop
	datatype kind =
		 Unit
		 | Prod of kind * kind
		 | Fst of kind
		 | Snd of kind
		 | Subset of kind * string * prop
		 | Time
		 | Other of Theory.kind
	datatype constr =
		 TT
		 | Pair of constr * constr
	end

(* constructors *)
signature CONSTR = sig
    type kind
    type constr
    val T0 : constr
    val T1 : constr
    val Tadd : constr * constr -> constr
    val Tmax : constr * constr -> constr
end

functor MakeConstr (structure Theory : TIME_THEORY) = struct
	(* simple kind without arrows *)
	datatype kind = 
		 Type
		 | Other of Theory.kind
	datatype constr = 
		 Var of var
		 | Arrow of constr * constr * constr
		 | Unit
		 | Prod of constr * constr
		 | Sum of constr * constr
		 | Uni of kind * string * constr
		 | Ex of kind * string * constr
		 (* the kind of Recur is Theory.kind => Type, to allow for change of index *)
		 | Recur of Theory.kind * string * string * constr
		 (* the first operant of App can only be a recursive type*)
		 | App of constr * constr
		 | T0
		 | T1
		 | Tadd of constr * constr
		 | Tmax of constr * constr
		 | Other of Theory.constr

	end

(* expressions *)
functor MakeExpr (structure Constr : CONSTR) = struct
	open Constr
	datatype expr =
		 Var of var
		 | App of expr * expr
		 | Abs of constr * string * expr (* string is the variable name only for debug purpose *)
		 (* convenience facilities *)
		 | Fix of constr * string * expr
		 | Let of string * expr * expr
		 | Ascript of expr * constr
		 | AscriptTime of expr * constr
		 (* unit type *)
		 | TT
		 (* product type *)
		 | Pair of expr * expr
		 | Fst of expr
		 | Snd of expr
		 (* sum type *)
		 | Inl of constr * expr
		 | Inr of constr * expr
		 | Match of expr * string * expr * string * expr
		 (* universal *)
		 | Tabs of kind * string * expr
		 | Tapp of expr * constr
		 (* existential *)
		 | Pack of constr * constr * expr
		 | Unpack of expr * constr * constr * string * string * expr
		 (* recursive type *)
		 | Fold of constr * expr
		 | Unfold of expr
	end			       

structure TimeTheory = MakeTimeTheory (structure Theory = Theory)
structure Constr = MakeConstr (structure Theory = TimeTheory)
structure Expr = MakeExpr (structure Constr = Constr)
open Theory
open TimeTheory
open Constr
open Expr

(* kinding context *)
type kcontext = (string * kind) list
fun add_kinding (name, k) kctx = (name, k) :: kctx

(* typing context *)
type tcontext = (string * constr) list
fun add_typing (name, c) tctx = (name, c) :: tctx

exception Unimpl

fun lookup (x : var) (tctx : tcontext) : constr option = NONE

fun var_toString (x : var) : string = Int.toString x
fun expr_toString (e : expr) : string =
    case e of
	Var x => var_toString x
      | App (e1, e2) => "(" ^ expr_toString e1 ^ " " ^ expr_toString e2 ^ ")"
      | _ => raise Unimpl

fun constr_toString (c : constr) : string =
    case c of
	Arrow (c1, d, c2) => "(" ^ constr_toString c1 ^ " time " ^ constr_toString d ^ " -> " ^ constr_toString c2 ^ ")"
      | _ => raise Unimpl

fun a + b = Tadd (a, b)
infix 3 $
fun a $ b = Tmax (a, b)

fun subst (v : constr) (b : constr) : constr = raise Unimpl
						     
datatype 'a result =
	 OK of 'a
	 | Failed of string

(* use exception and cell to mimic the Error and Writer monads *)
local								    

    exception Fail of string

    fun runError m _ =
	OK (m ())
	handle
	Fail msg => Failed msg

    val acc = ref ([] : prop list)

    fun tell a = acc := !acc @ a

    fun runWriter m _ =
	(acc := []; let val r = m () in (r, !acc) end)

    fun time_le (kctx : kcontext) (c : constr) (c' : constr) = raise Unimpl

    fun wfkind (kctx : kcontext) (k : kind) = raise Unimpl

    fun subkinding (kctx : kcontext) (k : kind) (k' : kind) = raise Unimpl

    fun kinding (kctx : kcontext) (c : constr) : kind = raise Unimpl

    fun check_kind kctx t k = subkinding kctx (kinding kctx t) k

    fun join (c : constr) (c' : constr) : constr = raise Unimpl

    fun subtyping (kctx : kcontext) (c : constr) (c' : constr) =
	case (c, c') of
	    (Arrow (c1, d, c2), Arrow (c1', d', c2')) =>
	    (subtyping kctx c1' c1;
	     time_le kctx d d';
	     subtyping kctx c2 c2')
	  | _ => 
	    raise Unimpl

    fun mismatch e expect have =  "Type mismatch for " ^ (expr_toString e) ^ ": expect " ^ expect ^ " have " ^ (constr_toString have)
    fun mismatch_anno expect have =  "Type annotation mismatch: expect " ^ expect ^ " have " ^ (constr_toString have)

    fun is_value (e : expr) : bool = raise Unimpl

    fun typing (ctx : kcontext * tcontext) (e : expr) : constr * constr =
	let val (kctx, tctx) = ctx in
	    case e of
		Var x =>
		(case lookup x tctx of
      		     SOME t => (t, T0)
      		   | NONE => raise Fail ("Unbound variable " ^ var_toString x))
	      | App (e1, e2) =>
		let val (t1, d1) = typing ctx e1 in
    		    case t1 of
    			Arrow (t2, d, t) =>
    			let val (t2', d2) = typing ctx e2 in
			    subtyping kctx t2' t2;
    			    (t, d1 + d2 + T1 + d) 
			end
    		      | t1' =>  raise Fail (mismatch e "(_ time _ -> _)" t1')
		end
	      | Abs (t, varname, e) => 
		let val _ = check_kind kctx t Type
		    val (t1, d) = typing (kctx, (add_typing (varname, t) tctx)) e in
		    (Arrow (t, d, t1), T0)
		end
	      | TT => (Unit, T0)
	      | Pair (e1, e2) => 
		let val (t1, d1) = typing ctx e1 
		    val (t2, d2) = typing ctx e2 in
		    (Prod (t1, t2), d1 + d2)
		end
	      | Fst e => 
		let val (t, d) = typing ctx e in 
		    case t of
			Prod (t1, t2) => (t1, d + T1)
		      | t' => raise Fail (mismatch e "(_ * _)" t')
		end
	      | Snd e => 
		let val (t, d) = typing ctx e in 
		    case t of
			Prod (t1, t2) => (t2, d + T1)
		      | t' => raise Fail (mismatch e "(_ * _)" t')
		end
	      | Inl (t2, e) => 
		let val (t1, d) = typing ctx e in
		    check_kind kctx t2 Type;
		    (Sum (t1, t2), d)
		end
	      | Inr (t1, e) => 
		let val (t2, d) = typing ctx e in
		    check_kind kctx t1 Type;
		    (Sum (t1, t2), d)
		end
	      | Match (e, name1, e1, name2, e2) => 
		let val (t, d) = typing ctx e in
		    case t of
			Sum (t1, t2) => 
			let val (tr1, d1) = typing (kctx, add_typing (name1, t1) tctx) e1
			    val (tr2, d2) = typing (kctx, add_typing (name2, t2) tctx) e2
			    val tr = join tr1 tr2 in
			    (tr, d + T1 + d1 $ d2)
			end
		      | t' => raise Fail (mismatch e "(_ + _)" t')
		end
	      | Tabs (k, name, e) => 
		if is_value e then
		    let val _ = wfkind kctx k 
			val (t, _) = typing (add_kinding (name, k) kctx, tctx) e in
			(Uni (k, name, t), T0)
		    end 
		else
		    raise Fail ("The body of a universal abstraction must be a value")
	      | Tapp (e, c) =>
		let val (t, d) = typing ctx e in
		    case t of
			Uni (k, name, t1) => 
			(check_kind kctx c k;
			 (subst c t1, d + T1))
		      | t' => raise Fail (mismatch e "(forall _ : _, _)" t')
		end
	      | Fold (t, e) => 
		(case t of
		     Constr.App (t1 as Recur (_, _, _, t2), c) =>
		     let val (t3, d) = typing ctx e in
			 check_kind kctx t Type;
			 subtyping kctx t3 (subst c (subst t1 t2));
			 (t, d)
		     end
		   | t' => raise Fail (mismatch_anno "((recur (_ :: _) (_ : _), _) [_])" t'))
	      | Unfold e =>
	      	let val (t, d) = typing ctx e in
	      	    case t of
	      		Constr.App (t1 as Recur (_, _, _, t2), c) =>
			(subst c (subst t1 t2), d + T1)
		      | t' => raise Fail (mismatch e "((recur (_ :: _) (_ : _), _) [_])" t')
	      	end
	      | Pack (t, c, e) =>
		(case t of
		     Ex (k, _, t1) =>
		     let val _ = check_kind kctx t Type
			 val _ = check_kind kctx c k
			 val (t2, d) = typing ctx e in
			 subtyping kctx t2 (subst c t1);
			 (t, d)
		     end
		   | t' => raise Fail (mismatch_anno "(ex _ : _, _)" t'))
	      | Unpack (e1, t, d, type_var, expr_var, e2) => 
		let val _ = check_kind kctx t Type
		    val _ = check_kind kctx d Time
		    val (t1, d1) = typing ctx e1 in
		    case t1 of
			Ex (k, _, t1') => 
			let val (t2, d2) = typing (add_kinding (type_var, k) kctx, add_typing (expr_var, t1') tctx) e2 in
			    subtyping kctx t2 t;
			    time_le kctx d2 d;
			    (t, d1 + T1 + d)
			end
		      | t1' => raise Fail (mismatch e1 "(ex _ : _, _)" t1')
		end
	      | _  => raise Unimpl
	end

in								     

fun vcgen (ctx : kcontext * tcontext) (e : expr) : ((constr * constr) * prop list) result =
    runError (runWriter (fn _ => typing ctx e)) ()

end

val result = vcgen ([], []) (Var 0)
val _ =
    case result of
	OK _ => print "OK\n"
      | Failed msg => print ("Failed: " ^ msg ^ "\n")
