structure Util = struct

infixr 0 $
infixr 0 !!
         
fun f $ x = f x

fun interleave xs ys =
    case xs of
	x :: xs' => x :: interleave ys xs'
      | nil => ys
fun take n ls = if n < 0 then [] else if n > length ls then ls else List.take (ls, n)
fun drop n ls = if n < 0 then ls else if n > length ls then [] else List.drop (ls, n)
fun skip start len ls = take start ls @ drop (start + len) ls
fun remove n ls = skip n 1 ls
fun lastn n ls =
  let
    val len = length ls
  in
    if n >= len then ls
    else
      drop (len - n) ls
  end
fun isPrefix eq xs ys =
  case (xs, ys) of
      ([], _) => true
    | (x :: xs, y :: ys) => eq (x, y) andalso isPrefix eq xs ys
    | _ => false
val Cons = op::

fun sprintf s ls =
    String.concat (interleave (String.fields (fn c => c = #"$") s) ls)
fun printf s ls = print $ sprintf s ls
fun println s = print (s ^ "\n")
fun trace s a = (println s; a)
fun trace_noln s a = (print s; a)
fun trace_around begin_mark end_mark f =
  let
    val () = print begin_mark
    val v = f ()
    val () = println end_mark
  in
    v
  end

fun isNone opt = not (isSome opt)
fun default v opt = getOpt (opt, v)
fun lazy_default def opt = 
    case opt of
        SOME a => a
      | NONE => def ()
fun opt !! def = lazy_default def opt
fun option2list a =
  case a of
      SOME a => [a]
    | NONE => []

fun pair2list (a, b) = [a, b]                 
                
fun min (a, b) = if a < b then a else b
                                      
val join = String.concatWith
fun prefix fix s = fix ^ s
fun suffix fix s = s ^ fix
fun surround pre post s = pre ^ s ^ post
fun indent msg = map (fn s => "  " ^ s) msg
fun join_lines ls = (join "" o map (suffix "\n")) ls
fun join_prefix fix ls = (join "" o map (prefix fix)) ls
fun join_suffix fix ls = (join "" o map (suffix fix)) ls
fun substr start len s = substring (s, start, min (len, size s - start))
                                                      
fun str_ls_fn pre post f ls = (surround pre post o join ", " o map f) ls
fun str_ls f ls = str_ls_fn "[" "]" f ls
fun str_ls_paren f ls = str_ls_fn "(" ")" f ls
fun str_pair (f, g) (a, b) = sprintf "($, $)" [f a, g b]
fun str_opt_default def f opt = default def $ Option.map f opt
fun str_opt a = str_opt_default "" a
val str_large_int = LargeInt.toString
(* val str_int = Int.toString *)
fun str_int i =
  let
    val ord0 = Char.ord #"0"
    fun d2c d = Char.chr (ord0 + d)
    fun nat2list i =
      if i < 10 then [d2c i]
      else d2c (i mod 10) :: (nat2list (i div 10))
    val (sgn, abs) = if i < 0 then ([#"-"], ~i) else ([], i)
  in
    String.implode $ sgn @ (rev $ nat2list abs)
  end
fun str_bool b = if b then "true" else "false"
val str_char = Char.toCString

fun id x = x
val return1 = id
fun return2 a1 a2 = a2
fun return3 a1 a2 a3 = a3
fun return4 a1 a2 a3 a4 = a4
fun const_fun c _ = c
fun ignore x = const_fun () x
fun self_compose n f =
    if n <= 0 then
      id
    else
      (self_compose (n - 1) f) o f
                                   
fun range n = List.tabulate (n, id)
fun repeat n a = List.tabulate (n, const_fun a)
                               
fun nth_error ls n =
  SOME (List.nth (ls, n)) handle Subscript => NONE

fun fst (a, b) = a
fun snd (a, b) = b
fun mapFst f (a, b) = (f a, b)
fun mapSnd f (a, b) = (a, f b)
fun mapPair (fa, fb) (a, b) = (fa a, fb b)
fun mapPair' fa fb (a, b) = (fa a, fb b)
fun curry f a b = f (a, b)
fun uncurry f (a, b) = f a b
fun swap f (a, b) = f (b, a)
fun flip f a b = f b a
fun map_triple (f1, f2, f3) (a1, a2, a3) = (f1 a1, f2 a2, f3 a3)
fun map4 f (a, b, c, d) = (a, b, c, f d)
fun map3_4 f (a, b, c, d) = (a, b, f c, d)
fun map2_3 f (a, b, c) = (a, f b, c)
fun attach_fst a b = (a, b)
fun attach_snd b a = (a, b)
(* fun add_idx ls = ListPair.zip (range (length ls), ls) *)
fun mapPair2 f1 f2 (a1, a2) (b1, b2) = (f1 (a1, b1), f2 (a2, b2))
fun add_pair a b = mapPair2 op+ op+ a b

fun findWithIdx f xs =
    let
      fun loop base xs =
          case xs of
              [] => NONE
            | x :: xs =>
              if f (base, x) then
                SOME (base, x)
              else
                loop (base + 1) xs
    in
      loop 0 xs
    end
      
fun findOptionWithIdx f xs =
    let
      fun loop base xs =
          case xs of
              [] => NONE
            | x :: xs =>
              case f (base, x) of
                  SOME a =>
                  SOME a
                | NONE =>
                  loop (base + 1) xs
    in
      loop 0 xs
    end
      
fun findi f xs = findWithIdx (f o snd) xs
fun indexOf f = Option.map fst o findi f
                             
fun mapPartialWithIdx f xs =
    let
      fun iter (x, (n, acc)) =
          let
            val acc =
                case f (n, x) of
                    SOME b => (n, b) :: acc
                  | NONE => acc
          in
            (n + 1, acc)
          end
    in
      rev $ snd $ foldl iter (0, []) xs
    end
      
fun foldlWithIdx f init xs = fst $ foldl (fn (x, (acc, n)) => (f (x, acc, n), n + 1)) (init, 0) xs
fun foldli f = foldlWithIdx (fn (x, acc, n) => f (n, x, acc))
fun foldrWithIdx start f init xs = fst $ foldr (fn (x, (acc, n)) => (f (x, acc, n), n + 1)) (init, start) xs
fun foldri f = foldrWithIdx 0 (fn (x, acc, n) => f (n, x, acc))
fun foldri' f acc ls =
  let
    val len = length ls
  in
    foldri (fn (i, x, acc) => f (len-1-i, x, acc)) acc ls
  end
fun mapWithIdx f ls = rev $ foldlWithIdx (fn (x, acc, n) => f (n, x) :: acc) [] ls
val mapi = mapWithIdx
fun appi f = ignore o mapi f
fun mapr f = foldr (fn (x, acc) => f x :: acc) []
fun enumerate c : ('a, 'b) Enum.enum = fn f => (fn init => List.foldl f init c)
                                 
fun update i f ls = mapi (fn (i', a) => if i' = i then f a else a) ls
                         
(* fun find_idx (x : string) ctx = find_by_snd_eq op= x (add_idx ctx) *)
fun is_eq_snd (x : string) (i, y) = if y = x then SOME i else NONE
fun find_idx x ctx = findOptionWithIdx (is_eq_snd x) ctx
fun is_eq_fst_snd (x : string) (i, (y, v)) = if y = x then SOME (i, v) else NONE
fun find_idx_value x ctx = findOptionWithIdx (is_eq_fst_snd x) ctx

datatype ('a, 'b) result =
	 OK of 'a
	 | Failed of 'b
val Continue = OK
val ShortCircuit = Failed
fun is_ShortCircuit a =
    case a of
        OK _ => NONE
      | Failed a => SOME a

val zip = ListPair.zip
val unzip = ListPair.unzip
fun map2 f = curry $ ListPair.mapEq $ uncurry f
val app2 = ListPair.app
fun unzip3 ls = let val ((a, b), c) = mapFst unzip $ unzip $ map (fn (a, b, c) => ((a, b), c)) ls in (a, b, c) end

fun allSome f (xs : 'a list) =
    let
      exception Error of int * 'a
      fun iter (x, (n, acc)) =
          let
            val acc =
                case f x of
                    SOME y => y :: acc
                  | NONE => raise Error (n, x)
          in
            (n + 1, acc)
          end
      val ret = OK $ rev $ snd $ foldl iter (0, []) xs
                handle Error e => Failed e
    in
      ret
    end

fun to_hd i l = List.nth (l, i) :: take i l @ drop (i + 1) l

exception Impossible of string
exception Unimpl of string

fun singleton x = [x]
fun mem eq x ls = List.exists (fn y => eq (y, x)) ls
fun subset eq a b =
    List.all (fn x => mem eq x b) a
fun intersection eq a b = List.filter (fn x => mem eq x b) a
fun diff eq a b = List.filter (fn x => not (mem eq x b)) a
fun dedup eq xs =
    case xs of
        [] => []
      | x :: xs => x :: dedup eq (diff eq xs [x])

fun foldl' f init xs =
    case xs of
        [] => init
      | x :: xs => foldl f x xs

fun foldl_nonempty f xs =
    case xs of
        [] => raise Impossible "fold_nonempty(): got []"
      | x :: xs => foldl f x xs

fun foldlM (bind, return) f init xs =
    let
      fun loop init xs =
          case xs of
              [] => return init
            | x :: xs => bind (f (x, init)) (fn y => loop y xs)
    in
      loop init xs
    end

fun opt_bind a b =
    case a of
        NONE => NONE
      | SOME a => b a
fun opt_return a = SOME a
                        
fun error_bind a b =
    case a of
        Failed _ => a
      | OK a => b a
fun error_return v = OK v

fun foldlM_Error f = foldlM (error_bind, error_return) f

fun max a b = if a < b then b else a
fun max_ls init ls = foldl (uncurry max) init ls
fun sum ls = foldl op+ 0 ls
fun max_from_0 ls = max_ls 0 ls

fun write_file (filename, s) =
    let
      val out =  TextIO.openOut filename
      val () = TextIO.output (out, s)
      val () = TextIO.closeOut out
    in
      ()
    end
fun write_file' a = curry write_file a

(* fun read_file filename = *)
(*     let *)
(*       val ins = TextIO.openIn filename *)
(*       val s = TextIO.input ins *)
(*       val _ = TextIO.closeIn ins *)
(*     in *)
(*       s *)
(*     end *)
      
fun read_file filename =
    let
      (* val () = println $ "read_file(): " ^ filename *)
      open TextIO
      val ins = openIn filename
      fun loop lines =
          case inputLine ins of
              SOME ln => loop (ln :: lines)
            | NONE => lines
      val lines = rev $ loop []
      val () = closeIn ins
      val line = String.concat lines
      (* val () = println line *)
    in
      line
    end
      
fun read_lines filename =
    let
      open TextIO
      val ins = openIn filename
      fun loop lines =
          case inputLine ins of
              SOME ln => loop (String.substring (ln, 0, String.size ln - 1) :: lines)
            | NONE => lines
      val lines = rev $ loop []
      val () = closeIn ins
    in
      lines
    end
      
fun trim s =
    let
      fun first_non_space s =
          let
            val len = String.size s
            fun loop n =
                if n >= len then
                  NONE
                else
                  if Char.isSpace $ String.sub (s, n)  then
                    loop (n + 1)
                  else
                    SOME n
          in
            loop 0
          end
      fun last_non_space s =
          let
            val len = String.size s
            fun loop n =
                if n < 0 then
                  NONE
                else
                  if Char.isSpace $ String.sub (s, n)  then
                    loop (n - 1)
                  else
                    SOME n
          in
            loop (len - 1)
          end
      val first = first_non_space s
      val last = last_non_space s
    in
      case (first, last) of
          (SOME first, SOME last) =>
          if first <= last then
            String.substring (s, first, last - first + 1)
          else
            ""
        | _ => ""
    end
      
fun concatMap f ls = (List.concat o map f) ls
fun concatMapi f ls = (List.concat o mapi f) ls
fun concatRepeat n v = List.concat $ repeat n v

structure Range = struct

type range = int * int

val range = id
              
fun zero_to length = (0, length)

fun foldl f init (start, len) =
    if len <= 0 then
      init
    else
      foldl f (f (start, init)) (start + 1, len - 1)

fun for f init range = foldl f init range

fun map f range = rev $ foldl (fn (i, acc) => f i :: acc) [] range
fun to_list a = map id a
                             
fun app f range = foldl (fn (i, ()) => (f i; ())) () range

end

fun int_mapi f n = Range.map f $ Range.zero_to n
fun int_appi f n = Range.app f $ Range.zero_to n
fun int_mapi_rev f n = int_mapi (fn i => f $ n-1-i) n
val list_of_range = Range.to_list
fun int_concatMap f n = List.concat $ int_mapi f n
fun int_concatMap_rev f n = int_concatMap (fn i => f $ n-1-i) n
  
fun repeat_app f n = Range.app (fn _ => f ()) (Range.zero_to n)

(* uninhabited *)
datatype empty = Empty of empty
fun exfalso (x : empty) = raise Impossible "type empty shouldn't have inhabitant"

fun inc n = n + 1
fun dec n = n - 1
fun add a b = a + b
                  
fun unop_ref f r = r := f (!r)
fun binop_ref f r x = r := f (!r) x
fun inc_ref r = r := !r + 1
fun dec_ref r = r := !r - 1
fun push xs x = x :: xs
fun push_ref r x = binop_ref push r x
fun copy_ref r = ref $ !r

datatype ('a, 'b) sum = 
         inl of 'a
         | inr of 'b
fun is_inl x = case x of inl a => SOME a | inr _ => NONE
fun is_inr x = case x of inr a => SOME a | inl _ => NONE
fun assert_inl x =
  case x of
      inl a => a
    | _ => raise Impossible "assert_inl"
fun assert_inr x =
  case x of
      inr a => a
    | _ => raise Impossible "assert_inr"
fun map_inl f s =
    case s of
        inl e => inl $ f e
      | inr _ => s

fun map_inr f s =
    case s of
        inl _ => s
      | inr e => inr $ f e

fun map_inl_inr f1 f2 s =
    case s of
        inl e => inl $ f1 e
      | inr e => inr $ f2 e

fun unify_sum f1 f2 s =
  case s of
      inl e => f1 e
    | inr e => f2 e
val app_inl_inr = unify_sum
val str_sum = unify_sum

fun filter_inl ls = List.mapPartial is_inl ls
fun filter_inr ls = List.mapPartial is_inr ls
                    
fun find_by_snd p ls =
    Option.map fst (List.find (fn (_, y) => p y) ls)
fun find_by_snd_eq eq x ls = find_by_snd (curry eq x) ls
                                         
fun findOption f xs =
    case xs of
        [] => NONE
      | x :: xs =>
        case f x of
            SOME y => SOME y
          | NONE => findOption f xs
                               
fun partitionOption f xs =
    case xs of
        [] => ([], [])
      | x :: xs =>
        let
          val (ys, zs) = partitionOption f xs
        in
          case f x of
              SOME y => (y :: ys, zs)
            | _ => (ys, x :: zs)
        end

fun partitionSum f xs =
    case xs of
        [] => ([], [])
      | x :: xs =>
        let
          val (ys, zs) = partitionSum f xs
        in
          case f x of
              inl y => (y :: ys, zs)
            | inr z => (ys, z :: zs)
        end

fun partition3 f ls = foldr (
    fn (a, (xs, ys, zs)) =>
       case f a of
           inl x => (x :: xs, ys, zs)
         | inr (inl y) => (xs, y :: ys, zs)
         | inr (inr z) => (xs, ys, z :: zs)
  ) ([], [], []) ls
                            
fun partitionOptionFirst f xs =
    case xs of
        [] => NONE
      | x :: xs =>
        case f x of
            SOME y => SOME (y, xs)
          | _ =>
            case partitionOptionFirst f xs of
                SOME (a, rest) => SOME (a, x :: rest)
              | NONE => NONE

fun firstSuccess f xs = foldl (fn (x, acc) => case acc of SOME _ => acc | NONE => f x) NONE xs
                              
fun b2o b = if b then SOME () else NONE
                                     
fun b2i b = if b then 1 else 0
                                     
fun assert_m p msg = if p () then () else raise Impossible $ "Assert failed: " ^ msg ()
fun assert_b_m msg b = assert_m (const_fun b) msg
fun assert p msg = assert_m p (const_fun msg)
fun assert_b msg b = assert (const_fun b) msg

fun assert_nil ls =
    case ls of
        [] => ()
      | x :: xs => raise Impossible "assert_nil fails"
                            
fun assert_cons ls =
    case ls of
        x :: xs => (x, xs)
      | [] => raise Impossible "assert_cons fails"
                            
fun assert_cons2 ls =
    case ls of
        x1 :: x2 :: xs => (x1, x2, xs)
      | _ => raise Impossible "assert_cons2 fails"
                            
fun assert_cons3 ls =
    case ls of
        x1 :: x2 :: x3 :: xs => (x1, x2, x3, xs)
      | _ => raise Impossible "assert_cons3 fails"
                   
fun assert_last es =
  let
    val es = rev es
    val (e, es) = assert_cons es
    val es = rev es
  in
    (es, e)
  end
    
fun assert_SOME a = case a of SOME v => v | NONE => raise Impossible "assert_SOME()"
fun assert_SOME_m err a = case a of SOME v => v | NONE => err ()
val assert_some = assert_SOME
val assert_some_m = assert_SOME_m

fun find_unique ls name =
  if not (mem op= name ls) then
    name
  else
    let fun loop n =
	  let val name' = name ^ "_" ^str_int n in
	    if not (mem op= name' ls) then name' else loop (n + 1)
	  end in
      loop 2
    end

fun isEqual r = r = EQUAL

fun split_dir_file filename =
  let
    val dir_file = OS.Path.splitDirFile filename
  in
    (#dir dir_file, #file dir_file)
  end

fun join_dir_file (dir, file) = OS.Path.joinDirFile {dir = dir, file = file}
val join_dir_file' = curry join_dir_file

fun split_base_ext file =
  let
    val base_ext = OS.Path.splitBaseExt file
  in
    (#base base_ext, #ext base_ext)
  end

fun join_base_ext (base, ext) = OS.Path.joinBaseExt {base = base, ext = ext}
                      
fun split_dir_file_ext filename =
  let
    val (dir, file) = split_dir_file filename
    val (base, ext) = split_base_ext file
  in
    (dir, base, ext)
  end

(* a replacement for ';' because ';''s precedence is too low (lower than 'if-then-else' and 'handle') *)    
(* infixr 0 @@ *)
(* fun a @@ b = (a; b) *)

fun scan_fn scan radix s = StringCvt.scanString (scan radix) s
fun str2int_fn scan s =
  let
    val r = 
        if String.isPrefix "0x" s then
          scan_fn scan StringCvt.HEX s
        else
          scan_fn scan StringCvt.DEC s
  in
    r
    (* case r of *)
    (*     SOME a => a *)
    (*   | NONE => raise Impossible $ "str2int_fn() failed on: " ^ s *)
  end
                                        
fun scan a = scan_fn Int.scan a
fun str2int a = str2int_fn Int.scan a
fun scan_large_int a = scan_fn LargeInt.scan a
fun str2large_int a = str2int_fn LargeInt.scan a
                                        
fun hex_fn fmt nBytes i =
  let
    val n = nBytes * 2
    val s = fmt StringCvt.HEX i
    val len = String.size s
    val s = if len > n then String.extract (s, len-n, NONE)
            else s
    val s = StringCvt.padLeft #"0" n s
  in
    s
  end

fun hex len n = hex_fn Int.fmt len n
fun hex_large_int len n = hex_fn LargeInt.fmt len n
(* fun hex_str len s = hex_large_int len $ str2large_int s *)

(* todo: implement *)
fun short_str s =
  "0x" ^ String.translate (fn c => hex 2 $ Char.ord c) s

fun bounded_minus a b = max 0 $ a - b

(* types that avoids the use of parameter-less constructor NONE to prevent misspelling in patterns *)
datatype 'a my_option =
         None of unit
         | Some of 'a

datatype my_bool =
         True of unit
         | False of unit

fun imply a b = not a orelse b

fun sort f = ListMergeSort.sort (fn (a, b) => f (a, b) = GREATER)
val uniqueSort = ListMergeSort.uniqueSort

fun sort_string a = sort String.compare a
fun cmp_str_fst (a, b) = String.compare (fst a, fst b)

fun int_exp (base, exp) =
  if exp = 0 then 1
  else if exp > 0 then base * int_exp (base, exp-1)
  else raise Impossible "int_exp: exp < 0"

fun unzip_many n lss =
  if n <= 0 then []
  else
    let
      val (heads, lss) = unzip $ map assert_cons lss
      val r = heads :: unzip_many (n-1) lss
      val () = assert_b "unzip_many/length r = n" $ length r = n
    in
      r
    end
             
fun at_most_one_some_other_true fo fb ls =
  let
    exception Fail of string
    fun f (x, (i, acc)) =
      let
        val acc = 
            case fo x of
                SOME a =>
                (case acc of
                     SOME _ => raise Fail "two some"
                   | NONE => SOME (i, a)
                )
              | NONE => if fb x then acc else raise Fail "false"
      in
        (i+1, acc)
      end
    val r = SOME (snd $ foldl f (0, NONE) ls) handle Fail _ => NONE
  in
    case r of
        NONE => inr false
      | SOME NONE => inr true
      | SOME (SOME a) => inl a
  end
      
end
