(***************** pretty printers  **********************)    

structure EVM1PP = struct

open MicroTiMLPP
open EVM1
       
infixr 0 $
         
fun str_word_const c =
  case c of
      WCTT => "()"
    | WCInt n => str_int n
    | WCNat n => sprintf "#$" [str_int n]
    | WCBool b => str_bool b
    | WCByte c => Char.toCString c
    | WCLabel l => "l_" ^ str_int l
                                
fun str_inst a =
  case a of
      ADD => "ADD"
    | MUL => "MUL"
    | SUB => "SUB"
    | DIV => "DIV"
    | SDIV => "SDIV"
    | MOD => "MOD"
    | LT => "LT"
    | GT => "GT"
    | SLT => "SLT"
    | SGT => "SGT"
    | EQ => "EQ"
    | ISZERO => "ISZERO"
    | AND => "AND"
    | OR => "OR"
    | BYTE => "BYTE"
    | POP => "POP"
    | MLOAD => "MLOAD"
    | MSTORE => "MSTORE"
    | MSTORE8 => "MSTORE8"
    | JUMPI => "JUMPI"
    | JUMPDEST => "JUMPDEST"
    | UNFOLD => "UNFOLD"
    | NAT2INT => "NAT2INT"
    | INT2NAT => "INT2NAT"
    | BYTE2INT => "BYTE2INT"
    | PRINTC => "PRINTC"
    | DUP n => "DUP" ^ str_int n
    | SWAP n => "SWAP" ^ str_int n
    | _ => raise Impossible "str_inst()"

fun pp_w pp_t s w =
  let
    val pp_t = pp_t s
    fun space () = PP.space s 1
    fun str v = PP.string s v
    fun comma () = (str ","; space ())
    fun open_hbox () = PP.openHBox s
    fun open_vbox () = PP.openVBox s (PP.Rel 2)
    fun open_vbox_noindent () = PP.openVBox s (PP.Rel 0)
    fun close_box () = PP.closeBox s
  in
    case w of
        WConst c =>
        (
          open_hbox ();
          str "WConst";
          space ();
          str $ str_word_const c;
          close_box ()
        )
      | WUninit t =>
        (
          open_hbox ();
          str "WUninit";
          space ();
          str "(";
          pp_t t;
          str ")";
          close_box ()
        )
      | WBuiltin (name, t) =>
        (
          open_hbox ();
          str "WBuiltin";
          space ();
          str "(";
          str name;
          comma ();
          pp_t t;
          str ")";
          close_box ()
        )
      | WNever t =>
        (
          open_hbox ();
          str "WNever";
          space ();
          str "(";
          pp_t t;
          str ")";
          close_box ()
        )
  end
    
fun str_reg r = "r" ^ str_int r
                              
fun pp_inst (params as (str_i, pp_t, pp_w)) s inst =
  let
    val pp_inst = pp_inst params s
    val str_i = str_i o unInner
    val pp_t = pp_t s o unInner
    val pp_w = pp_w s o unInner
    fun space () = PP.space s 1
    fun str v = PP.string s v
    fun comma () = (str ","; space ())
    fun open_hbox () = PP.openHBox s
    fun open_vbox () = PP.openVBox s (PP.Rel 2)
    fun open_vbox_noindent () = PP.openVBox s (PP.Rel 0)
    fun close_box () = PP.closeBox s
  in
    case inst of
        PUSH (n, w) =>
        (
          open_hbox ();
          str $ "PUSH" ^ str_int n;
          space ();
          str "(";
          pp_w w;
          str ")";
          close_box ()
        )
      | VALUE_AppT t =>
        (
          open_hbox ();
          str $ "VALUE_AppT";
          space ();
          str "(";
          pp_t t;
          str ")";
          close_box ()
        )
      | VALUE_AppI i =>
        (
          open_hbox ();
          str $ "VALUE_AppI";
          space ();
          str "(";
          str $ str_i i;
          str ")";
          close_box ()
        )
  end

fun pp_insts (params as ((* pp_t,  *)pp_inst)) s insts =
  let
    val pp_insts = pp_insts params s
    (* val pp_t = pp_t s *)
    val pp_inst = pp_inst s
    fun space () = PP.space s 1
    fun str v = PP.string s v
    fun comma () = (str ","; space ())
    fun open_hbox () = PP.openHBox s
    fun open_vbox () = PP.openVBox s (PP.Rel 2)
    fun open_vbox_noindent () = PP.openVBox s (PP.Rel 0)
    fun close_box () = PP.closeBox s
  in
    case insts of
        ISCons bind =>
        let
          val (i, is) = unBind bind
        in
        (
	  open_vbox_noindent ();
          pp_inst i;
          space ();
          pp_insts is;
          close_box ()
        )
        end
      | JUMP => str "JUMP"
      | RETURN => str "RETURN"
      | ISDummy s => str s
  end

fun pp_hval (params as (str_i, str_s, str_k, pp_t, pp_insts)) s bind =
  let
    val pp_t = pp_t s
    val pp_insts = pp_insts s
    fun space () = PP.space s 1
    fun str v = PP.string s v
    fun comma () = (str ","; space ())
    fun open_hbox () = PP.openHBox s
    fun open_vbox () = PP.openVBox s (PP.Rel 2)
    fun open_vbox_noindent () = PP.openVBox s (PP.Rel 0)
    fun close_box () = PP.closeBox s
    val (itbinds, ((rctx, ts, i), insts)) = unBind bind
    val itbinds = unTeles itbinds
    val itbinds = map (map_inl_inr (mapPair' binder2str unOuter) (mapFst binder2str)) itbinds
  in
    open_vbox ();
    open_hbox ();
    str "Code";
    space ();
    str "(";
    app (app_inl_inr
           (fn (name, s) =>
              (str $ name;
               str ":"; space ();
               str $ str_s s;
               comma ()
           ))
           (fn (name, k) =>
              (str $ name;
               str "::"; space ();
               str $ str_k k;
               comma ()
           ))
        ) itbinds;
    close_box ();
    space ();
    open_vbox_noindent ();
    open_hbox ();
    str "{";
    Rctx.appi (fn (r, t) =>
              (str $ str_reg r;
               str ":"; space ();
               pp_t t;
               comma ()
              )) rctx;
    str "}";
    close_box ();
    comma ();
    open_vbox_noindent ();
    str "["; space ();
    app (fn t =>
            (pp_t t;
             comma ()
        )) ts;
    str "]";
    close_box ();
    comma ();
    str $ str_i i;
    comma ();
    pp_insts insts;
    str ")";
    close_box ();
    close_box ()
  end
    
fun pp_prog (pp_hval, pp_insts) s (heap, insts) =
  let
    val pp_hval = pp_hval s
    val pp_insts = pp_insts s
    fun space () = PP.space s 1
    fun str v = PP.string s v
    fun comma () = (str ","; space ())
    fun open_hbox () = PP.openHBox s
    fun open_vbox () = PP.openVBox s (PP.Rel 2)
    fun open_vbox_noindent () = PP.openVBox s (PP.Rel 0)
    fun close_box () = PP.closeBox s
  in
    open_vbox_noindent ();
    app (fn ((l, name), h) =>
            (str $ sprintf "$ <$>" [str_int l, name];
             str ":"; space ();
             pp_hval h;
             space ()
        )) heap;
    pp_insts insts;
    close_box ()
  end

open WithPP

fun pp_insts_to_fn ((* pp_t *)) s b =
  let
    val pp_w = pp_w pp_t
  in
    withPP ("", 80, s) (fn s => pp_insts ((* pp_t,  *)pp_inst (str_i, pp_t, pp_w)) s b)
  end
fun pp_insts_fn params = pp_insts_to_fn params TextIO.stdOut
fun pp_insts_to_string_fn params b =
  pp_to_string "pp_insts_to_string.tmp" (fn os => pp_insts_to_fn params os b)
    
fun pp_prog_to_fn (str_i, str_s, str_k, pp_t) s b =
  let
    val pp_w = pp_w pp_t
    val pp_insts = pp_insts ((* pp_t,  *)pp_inst (str_i, pp_t, pp_w))
  in
    withPP ("", 80, s) (fn s => pp_prog (pp_hval (str_i, str_s, str_k, pp_t, pp_insts), pp_insts) s b)
  end
fun pp_prog_fn params = pp_prog_to_fn params TextIO.stdOut
fun pp_prog_to_string_fn params b =
  pp_to_string "pp_prog_to_string.tmp" (fn os => pp_prog_to_fn params os b)
    
end
