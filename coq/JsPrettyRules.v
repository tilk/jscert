Require Import JsPreliminary JsPreliminaryAux JsPrettyInterm JsPrettyIntermAux JsSyntaxInfos JsInit.


(**************************************************************)
(** ** Implicit Types -- copied from JsPreliminary *)

Implicit Type b : bool.
Implicit Type n : number.
Implicit Type k : int.
Implicit Type s : string.
Implicit Type i : literal.
Implicit Type l lp : object_loc.
Implicit Type w : prim.
Implicit Type v vi vp vthis : value.
Implicit Type r : ref.
(*Implicit Type B : builtin.*)
Implicit Type ty : type.

Implicit Type rt : restype.
Implicit Type rv : resvalue.
Implicit Type lab : label.
Implicit Type labs : label_set.
Implicit Type R : res.
Implicit Type o : out.
Implicit Type ct : codetype.

Implicit Type x : prop_name.
Implicit Type str : strictness_flag.
Implicit Type m : mutability.
Implicit Type Ad : attributes_data.
Implicit Type Aa : attributes_accessor.
Implicit Type A : attributes.
Implicit Type Desc : descriptor.
Implicit Type D : full_descriptor.

Implicit Type L : env_loc.
Implicit Type E : env_record.
Implicit Type Ed : decl_env_record.
Implicit Type X : lexical_env.
Implicit Type O : object.
Implicit Type S : state.
Implicit Type C : execution_ctx.
Implicit Type P : object_properties_type.

Implicit Type e : expr.
Implicit Type p : prog.
Implicit Type t : stat.


(** added *)

Implicit Type c : call.
Implicit Type cstr : construct.
Implicit Type xs : list prop_name.

(** Useful for switch *)
Implicit Type sb : switchbody.
Implicit Type sc : switchclause.
(*Implicit Type scs : list switchclause.*)


(**************************************************************)
(** Shorthand **)

Definition vret := ret (T:=value).
Definition dret := ret (T:=full_descriptor).


(**************************************************************)
(** ** Reduction rules for global code (10.4.1) *)

Inductive red_javascript : prog -> out -> Prop :=

  | red_javascript_intro : forall S C p p' o o1,
      S = state_initial ->
      p' = add_infos_prog strictness_false p ->
      C = execution_ctx_initial (prog_intro_strictness p') ->
      red_expr S C (spec_binding_inst codetype_global None p' nil) o1 ->
      red_prog S C (javascript_1 o1 p') o ->
      red_javascript p o


(**************************************************************)
(** ** Reduction rules for programs (14) *)

with red_prog : state -> execution_ctx -> ext_prog -> out -> Prop :=

  (** Abort rule for programs *)

  | red_prog_abort : forall S C extp o,
      out_of_ext_prog extp = Some o ->
      abort o ->
      ~ abort_intercepted_prog extp ->
      red_prog S C extp o

  (** Program  (14.1) *)

  | red_javascript_intro_1 : forall S S' C p o,
      red_prog S' C p o ->
      red_prog S C (javascript_1 (out_void S') p) o

  | red_prog_nil : forall S C str,
      red_prog S C (prog_intro str nil) (out_ter S resvalue_empty)

  | red_prog_cons : forall S C str el els o1 o,
      red_prog S C (prog_intro str els) o1 -> (* This use of [prog_intro] as an intermediate form is not really nice... there should be an additionnal intermediate form there.  Furthermore, what's the use of this [str] here? *)
      red_prog S C (prog_1 o1 el) o ->
      red_prog S C (prog_intro str (els++(el::nil))) o

  | red_prog_1_funcdecl : forall S0 S C rv name args bd,
      red_prog S0 C (prog_1 (out_ter S rv) (element_func_decl name args bd)) (out_ter S rv)

  | red_prog_1_stat : forall S0 S C t rv o1 o,
      red_stat S C t o1 ->
      red_prog S C (prog_2 rv o1) o ->
      red_prog S0 C (prog_1 (out_ter S rv) (element_stat t)) o

  | red_prog_2 : forall S0 S C R R' rv,
      R' = (res_overwrite_value_if_empty rv R) ->
      red_prog S0 C (prog_2 rv (out_ter S R)) (out_ter S R')
        (* LATER: strange, the spec does not say the same thing as for blocs,
           i.e. it's being implicit about exceptions *)


(**************************************************************)
(** ** Reduction rules for statements (12) *)

with red_stat : state -> execution_ctx -> ext_stat -> out -> Prop :=

  (** Abort rule for statements *)

  | red_stat_abort : forall S C extt o, (* called red_stat_exception in POPL14 *)
      out_of_ext_stat extt = Some o ->
      abort o ->
      ~ abort_intercepted_stat extt ->
      red_stat S C extt o

  (** Block statement (12.1)
      -- See also the definition of [abort_intercepted_stat]. *)

  | red_stat_block_nil : forall S C, (* empty block, step 1 *)
      red_stat S C (stat_block nil) (out_ter S resvalue_empty)

  | red_stat_block_cons : forall S C t ts o1 o, (* step 1, and 2 (via abort rule) *)
      red_stat S C (stat_block ts) o1 ->
      red_stat S C (stat_block_1 o1 t) o ->
      red_stat S C (stat_block (ts++(t::nil))) o

  | red_stat_block_1 : forall S0 S C t rv o o1, (* step 3 *)
      red_stat S C t o1 ->
      red_stat S C (stat_block_2 rv o1) o ->
      red_stat S0 C (stat_block_1 (out_ter S rv) t) o

  | red_stat_block_2_throw : forall S0 S C R rv, (* step 4 *)
      res_type R = restype_throw ->
      red_stat S0 C (stat_block_2 rv (out_ter S R)) (out_ter S R)

  | red_stat_block_2_not_throw : forall S0 S C R R' rv, (* steps 5 and 6 *)
      res_type R <> restype_throw ->
      R' = (res_overwrite_value_if_empty rv R) ->
      red_stat S0 C (stat_block_2 rv (out_ter S R)) (out_ter S R')

  (** Variable declaration (12.2) *)

  | red_stat_var_decl_nil : forall S C,
      red_stat S C (stat_var_decl nil) (out_ter S res_empty)

  | red_stat_var_decl_cons : forall S C o o1 d ds,
      red_stat S C (stat_var_decl_item d) o1 ->
      red_stat S C (stat_var_decl_1 o1 ds) o ->
      red_stat S C (stat_var_decl (d::ds)) o

  | red_stat_var_decl_1 : forall S S0 C ds o rv,
      red_stat S C (stat_var_decl ds) o ->
      red_stat S0 C (stat_var_decl_1 (out_ter S rv) ds) o

  | red_stat_var_decl_item_none : forall S C x,
      red_stat S C (stat_var_decl_item (x,None)) (out_ter S x)

  | red_stat_var_decl_item_some : forall S C x e y1 o,
      red_spec S C (spec_identifier_resolution C x) y1 ->
      red_stat S C (stat_var_decl_item_1 x y1 e) o ->
      red_stat S C (stat_var_decl_item (x,Some e)) o

  | red_stat_var_decl_item_1 : forall S S0 C x e r y1 o,
      red_spec S C (spec_expr_get_value e) y1 ->
      red_stat S C (stat_var_decl_item_2 x r y1) o ->
      red_stat S0 C (stat_var_decl_item_1 x (ret S r) e) o

  | red_stat_var_decl_item_2 : forall S S0 C r v o o1 x,
      red_expr S C (spec_put_value r v) o1 ->
      red_stat S C (stat_var_decl_item_3 x o1) o ->
      red_stat S0 C (stat_var_decl_item_2 x r (ret S v)) o

  | red_stat_var_decl_item_3 : forall S S0 C x,
      red_stat S0 C (stat_var_decl_item_3 x (out_void S)) (out_ter S x)

  (** Expression (12.4) *)

  | red_stat_expr : forall S C e o y1,
       red_spec S C (spec_expr_get_value e) y1 ->
       red_stat S C (stat_expr_1 y1) o ->
       red_stat S C (stat_expr e) o

  | red_stat_expr_1 : forall S0 S C v,
       red_stat S0 C (stat_expr_1 (ret S v)) (out_ter S v)

  (** If statement (12.5) *)

  | red_stat_if : forall S C e1 t2 t3opt y1 o,
      red_spec S C (spec_expr_get_value_conv spec_to_boolean e1) y1 ->
      red_stat S C (stat_if_1 y1 t2 t3opt) o ->
      red_stat S C (stat_if e1 t2 t3opt) o

  | red_stat_if_1_true : forall S0 S C t2 t3opt o,
      red_stat S C t2 o ->
      red_stat S0 C (stat_if_1 (vret S true) t2 t3opt) o

  | red_stat_if_1_false : forall S0 S C t2 t3 o,
      red_stat S C t3 o ->
      red_stat S0 C (stat_if_1 (vret S false) t2 (Some t3)) o

  | red_stat_if_1_false_implicit : forall S0 S C t2,
      red_stat S0 C (stat_if_1 (vret S false) t2 None) (out_ter S resvalue_empty)

  (** Do-while statement (12.6.1)
      -- See also the definition of [abort_intercepted_stat].
  *)

  | red_stat_do_while : forall S C labs t1 e2 o,
      red_stat S C (stat_do_while_1 labs t1 e2 resvalue_empty) o ->
      red_stat S C (stat_do_while labs t1 e2) o

  | red_stat_do_while_1 : forall S C labs t1 e2 rv o1 o,
      red_stat S C t1 o1 ->
      red_stat S C (stat_do_while_2 labs t1 e2 rv o1) o ->
      red_stat S C (stat_do_while_1 labs t1 e2 rv) o

  | red_stat_do_while_2 : forall rv S0 S C labs t1 e2 rv_old R o,
      rv = (If res_value R = resvalue_empty then rv_old else res_value R) ->
      red_stat S C (stat_do_while_3 labs t1 e2 rv R) o ->
      red_stat S0 C (stat_do_while_2 labs t1 e2 rv_old (out_ter S R)) o

  | red_stat_do_while_3_continue : forall S C labs t1 e2 rv R o,
      res_type R = restype_continue /\ res_label_in R labs ->
      red_stat S C (stat_do_while_6 labs t1 e2 rv) o ->
      red_stat S C (stat_do_while_3 labs t1 e2 rv R) o

  | red_stat_do_while_3_not_continue : forall S C labs t1 e2 rv R o,
      ~ (res_type R = restype_continue /\ res_label_in R labs) ->
      red_stat S C (stat_do_while_4 labs t1 e2 rv R) o ->
      red_stat S C (stat_do_while_3 labs t1 e2 rv R) o

  | red_stat_do_while_4_break : forall S C labs t1 e2 rv R,
      res_type R = restype_break /\ res_label_in R labs ->
      red_stat S C (stat_do_while_4 labs t1 e2 rv R) (out_ter S rv)

  | red_stat_do_while_4_not_break : forall S C labs t1 e2 rv R o,
      ~ (res_type R = restype_break /\ res_label_in R labs) ->
      red_stat S C (stat_do_while_5 labs t1 e2 rv R) o ->
      red_stat S C (stat_do_while_4 labs t1 e2 rv R) o

  | red_stat_do_while_5_abort : forall S C labs t1 e2 rv R,
      res_type R <> restype_normal ->
      red_stat S C (stat_do_while_5 labs t1 e2 rv R) (out_ter S R)

  | red_stat_do_while_5_normal : forall S C labs t1 e2 rv R o,
      res_type R = restype_normal ->
      red_stat S C (stat_do_while_6 labs t1 e2 rv) o ->
      red_stat S C (stat_do_while_5 labs t1 e2 rv R) o

  | red_stat_do_while_6 : forall S0 S C labs t1 e2 rv y1 o,
      red_spec S C (spec_expr_get_value_conv spec_to_boolean e2) y1 ->
      red_stat S C (stat_do_while_7 labs t1 e2 rv y1) o ->
      red_stat S C (stat_do_while_6 labs t1 e2 rv) o

  | red_stat_do_while_7_false : forall S0 S C labs t1 e2 rv,
      red_stat S0 C (stat_do_while_7 labs t1 e2 rv (vret S false)) (out_ter S rv)

  | red_stat_do_while_7_true : forall S0 S C labs t1 e2 rv o,
      red_stat S C (stat_do_while_1 labs t1 e2 rv) o ->
      red_stat S0 C (stat_do_while_7 labs t1 e2 rv (vret S true)) o

  (** While statement (12.6.2)
      -- See also the definition of [abort_intercepted_stat]. *)

  (* Step 1: red_while_1 in POPL14 *)
  | red_stat_while : forall S C labs e1 t2 o,
      red_stat S C (stat_while_1 labs e1 t2 resvalue_empty) o ->
      red_stat S C (stat_while labs e1 t2) o

  (* Steps 2a and 2b: red_while_2a_2b in POPL14 *)
  | red_stat_while_1 : forall S C labs e1 t2 rv y1 o,
      red_spec S C (spec_expr_get_value_conv spec_to_boolean e1) y1 ->
      red_stat S C (stat_while_2 labs e1 t2 rv y1) o ->
      red_stat S C (stat_while_1 labs e1 t2 rv) o

  (* Step 2b False: red_while_2b'_false in POPL14 *)
  | red_stat_while_2_false : forall S0 S C labs e1 t2 rv,
      red_stat S0 C (stat_while_2 labs e1 t2 rv (vret S false)) (out_ter S rv)

  (* Step 2b True and 2c: red_while_2b'_true_2c in POPL14 *)
  | red_stat_while_2_true : forall S0 S C labs e1 t2 rv o1 o,
      red_stat S C t2 o1 ->
      red_stat S C (stat_while_3 labs e1 t2 rv o1) o ->
      red_stat S0 C (stat_while_2 labs e1 t2 rv (vret S true)) o

  (* Step 2d: red_while_2d in POPL14 *)
  | red_stat_while_3 : forall rv S0 S C labs e1 t2 rv' R o,
      rv' = (If res_value R <> resvalue_empty then res_value R else rv) ->
      red_stat S C (stat_while_4 labs e1 t2 rv' R) o ->
      red_stat S0 C (stat_while_3 labs e1 t2 rv (out_ter S R)) o

  (* Step 2e False: red_while_2e_false in POPL14 *)
  | red_stat_while_4_continue : forall S C labs e1 t2 rv R o,
      res_type R = restype_continue /\ res_label_in R labs ->
      red_stat S C (stat_while_1 labs e1 t2 rv) o ->
      red_stat S C (stat_while_4 labs e1 t2 rv R) o

  (* Step 2e True: red_while_2e_true in POPL14 *)
  | red_stat_while_4_not_continue : forall S C labs e1 t2 rv R o,
      ~ (res_type R = restype_continue /\ res_label_in R labs) ->
      red_stat S C (stat_while_5 labs e1 t2 rv R) o ->
      red_stat S C (stat_while_4 labs e1 t2 rv R) o

  (* Step 2e i True: red_while_2e_i_true in POPL14 *)
  | red_stat_while_5_break : forall S C labs e1 t2 rv R,
      res_type R = restype_break /\ res_label_in R labs ->
      red_stat S C (stat_while_5 labs e1 t2 rv R) (out_ter S rv)

  (* Step 2e i False: red_while_2e_i_false in POPL14 *)
  | red_stat_while_5_not_break : forall S C labs e1 t2 rv R o,
      ~ (res_type R = restype_break /\ res_label_in R labs) ->
      red_stat S C (stat_while_6 labs e1 t2 rv R) o ->
      red_stat S C (stat_while_5 labs e1 t2 rv R) o

  (* Step 2e ii True: red_while_2e_ii_true in POPL14 *)
  | red_stat_while_6_abort : forall S C labs e1 t2 rv R,
      res_type R <> restype_normal ->
      red_stat S C (stat_while_6 labs e1 t2 rv R) (out_ter S R)

  (* Step 2e ii False: red_while_2e_ii_false in POPL14 *)
  | red_stat_while_6_normal : forall S C labs e1 t2 rv R o,
      res_type R = restype_normal ->
      red_stat S C (stat_while_1 labs e1 t2 rv) o ->
      red_stat S C (stat_while_6 labs e1 t2 rv R) o


  (* Implicitly captured by the generic abort rule red_stat_abort:

  | red_stat_while_3_abort : forall rv S0 S C labs e1 t2 rv' R,
      res_type R <> restype_normal ->
      red_stat S0 C (stat_while_3 labs e1 t2 rv (out_ter S R)) (out_ter S R)

  *)

  (** For statement (12.6.3) *)

  | red_stat_for_none : forall S C labs eo2 eo3 t o, (* Steps 1 and 2 *)
      red_stat S C (stat_for_2 labs resvalue_empty eo2 eo3 t) o ->
      red_stat S C (stat_for labs None eo2 eo3 t) o

  | red_stat_for_some : forall S C labs e1 eo2 eo3 t o y1, (* Steps 1a and 1b *)
      red_spec S C (spec_expr_get_value e1) y1 ->
      red_stat S C (stat_for_1 labs y1 eo2 eo3 t) o ->
      red_stat S C (stat_for labs (Some e1) eo2 eo3 t) o

  | red_stat_for_1 : forall S0 S C labs v eo2 eo3 t o, (* Steps 1b and 2 *)
      red_stat S C (stat_for_2 labs resvalue_empty eo2 eo3 t) o ->
      red_stat S0 C (stat_for_1 labs (ret S v) eo2 eo3 t) o

  | red_stat_for_2_none : forall S C labs rv eo3 t o, (* Step 3a *)
      red_stat S C (stat_for_4 labs rv None eo3 t) o ->
      red_stat S C (stat_for_2 labs rv None eo3 t) o

  | red_stat_for_2_some : forall S C labs rv e2 eo3 t o y1, (* Step 3a *)
      red_spec S C (spec_expr_get_value_conv spec_to_boolean e2) y1 ->
      red_stat S C (stat_for_3 labs rv e2 y1 eo3 t) o ->
      red_stat S C (stat_for_2 labs rv (Some e2) eo3 t) o

  | red_stat_for_3_false : forall S0 S C labs rv e2 eo3 t, (* Step 3b *)
      red_stat S0 C (stat_for_3 labs rv e2 (vret S false) eo3 t) (out_ter S rv)

  | red_stat_for_3_not_false : forall S0 S C labs rv e2 v eo3 t o, (* Step 3b *)
      v <> false ->
      red_stat S C (stat_for_4 labs rv (Some e2) eo3 t) o ->
      red_stat S0 C (stat_for_3 labs rv e2 (vret S v) eo3 t) o

  | red_stat_for_4 : forall S C labs rv eo2 eo3 t o o1, (* Step 3b *)
      red_stat S C t o1 ->
      red_stat S C (stat_for_5 labs rv eo2 o1 eo3 t) o ->
      red_stat S C (stat_for_4 labs rv eo2 eo3 t) o

  | red_stat_for_5 : forall S0 S C labs rv rv' R eo2 eo3 t o, (* Step 3c *)
      rv' = (If res_value R <> resvalue_empty then res_value R else rv) ->
      red_stat S C (stat_for_6 labs rv' eo2 eo3 t R) o ->
      red_stat S0 C (stat_for_5 labs rv eo2 (out_ter S R) eo3 t) o

  | red_stat_for_6_break : forall S C labs rv R eo2 eo3 t, (* Step 3d *)
      res_type R = restype_break /\ res_label_in R labs ->
      red_stat S C (stat_for_6 labs rv eo2 eo3 t R) (out_ter S rv)

  | red_stat_for_6_not_break : forall S0 S C labs rv R eo2 eo3 t o, (* Step 3d *)
      res_type R <> restype_break \/ ~ res_label_in R labs ->
      red_stat S0 C (stat_for_7 labs rv eo2 eo3 t R) o ->
      red_stat S0 C (stat_for_6 labs rv eo2 eo3 t R) o

  | red_stat_for_7_abort : forall S C labs rv R eo2 eo3 t, (* Step 3e and 3ei *)
      res_type R <> restype_normal ->
      res_type R <> restype_continue \/ ~ res_label_in R labs ->
      red_stat S C (stat_for_7 labs rv eo2 eo3 t R) (out_ter S R)

  | red_stat_for_7_continue : forall S C labs rv R eo2 eo3 t o, (* Step 3e and 3ei *)
      res_type R = restype_normal \/ (res_type R = restype_continue /\ res_label_in R labs) ->
      red_stat S C (stat_for_8 labs rv eo2 eo3 t) o ->
      red_stat S C (stat_for_7 labs rv eo2 eo3 t R) o

  | red_stat_for_8_none : forall S C labs rv eo2 t o, (* Step 3f *)
      red_stat S C (stat_for_2 labs rv eo2 None t) o ->
      red_stat S C (stat_for_8 labs rv eo2 None t) o

  | red_stat_for_8_some : forall S C labs rv eo2 e3 t o y1, (* Step 3fi and 3fii *)
      red_spec S C (spec_expr_get_value e3) y1 ->
      red_stat S C (stat_for_9 labs rv eo2 e3 y1 t) o ->
      red_stat S C (stat_for_8 labs rv eo2 (Some e3) t) o

  | red_stat_for_9 : forall S0 S C labs rv v eo2 e3 t o o1, (* Step 3fii *)
      red_stat S C (stat_for_2 labs rv eo2 (Some e3) t) o ->
      red_stat S0 C (stat_for_9 labs rv eo2 e3 (vret S v) t) o

  | red_stat_for_var : forall S C labs ds eo2 eo3 t o o1, (* Step 1 *)
      red_stat S C (stat_var_decl ds) o1 ->
      red_stat S C (stat_for_var_1 o1 labs eo2 eo3 t) o ->
      red_stat S C (stat_for_var labs ds eo2 eo3 t) o

  | red_stat_for_var_1 : forall S0 S C R labs eo2 eo3 t o, (* Step 2 *)
      red_stat S C (stat_for_2 labs resvalue_empty eo2 eo3 t) o -> (* The rest of the specification is just a copy pasting of the other kind of [for]. *)
      red_stat S0 C (stat_for_var_1 (out_ter S R) labs eo2 eo3 t) o


  (** For-in statement: LATER (12.6.4) *)

  (** Continue statement (12.7) *)

  | red_stat_continue : forall S C lab,
      red_stat S C (stat_continue lab) (out_ter S (res_continue lab))

  (** Break statement (12.8) *)

  | red_stat_break : forall S C lab,
      red_stat S C (stat_break lab) (out_ter S (res_break lab))

  (** Return statement (12.9) *)

  | red_stat_return_none : forall S C,
      red_stat S C (stat_return None) (out_ter S (res_return undef))

  | red_stat_return_some : forall S C e o y1,
      red_spec S C (spec_expr_get_value e) y1 ->
      red_stat S C (stat_return_1 y1) o ->
      red_stat S C (stat_return (Some e)) o

  | red_stat_return_1 : forall S0 S C v,
      red_stat S0 C (stat_return_1 (ret S v)) (out_ter S (res_return v))

  (** With statement (12.10) *)

  | red_stat_with : forall S C e1 t2 y1 o,
      red_spec S C (spec_expr_get_value_conv spec_to_object e1) y1 ->
      red_stat S C (stat_with_1 t2 y1) o ->
      red_stat S C (stat_with e1 t2) o

  | red_stat_with_1 : forall S0 S S' C t2 l o lex lex' C',
      lex = execution_ctx_lexical_env C ->
      (lex',S') = lexical_env_alloc_object S lex l provide_this_true ->
      C' = execution_ctx_with_lex C lex' ->
      red_stat S' C' t2 o ->
      red_stat S0 C (stat_with_1 t2 (vret S l)) o

  (** Switch statement (12.11) *)

  | red_stat_switch : forall S C e o sb labs y1,
      red_spec S C (spec_expr_get_value e) y1 ->
      red_stat S C (stat_switch_1 y1 labs sb) o ->
      red_stat S C (stat_switch labs e sb) o

  | red_stat_switch_1_nodefault : forall S S0 C vi o o1 scs labs,
      red_stat S C (stat_switch_nodefault_1 vi resvalue_empty scs) o1 ->
      red_stat S C (stat_switch_2 o1 labs) o ->
      red_stat S0 C (stat_switch_1 (ret S vi) labs (switchbody_nodefault scs)) o

  | red_stat_switch_1_default: forall S S0 C o o1 vi scs1 scs2 ts1 labs,
      red_stat S C (stat_switch_default_A_1 false vi resvalue_empty scs1 ts1 scs2) o1 ->
      red_stat S C (stat_switch_2 o1 labs) o ->
      red_stat S0 C (stat_switch_1 (ret S vi) labs (switchbody_withdefault scs1 ts1 scs2)) o

  | red_stat_switch_2_break : forall S S0 C R rv lab labs, (* step 3 *)
      R = res_intro restype_break rv lab ->
      res_label_in R labs ->
      red_stat S0 C (stat_switch_2 (out_ter S R) labs) (out_ter S (res_normal rv))

  | red_stat_switch_2_normal : forall S0 S C rv labs, (* step 4 *)
      red_stat S0 C (stat_switch_2 (out_ter S rv) labs) (out_ter S rv)

  (** -- Switch without default case *)

  | red_stat_switch_nodefault_1_nil : forall S C vi rv o,
      red_stat S C (stat_switch_nodefault_5 rv nil) o ->
      red_stat S C (stat_switch_nodefault_1 vi rv nil) o

  | red_stat_switch_nodefault_1_cons : forall S C e vi rv ts scs o y1,
      red_spec S C (spec_expr_get_value e) y1 ->
      red_stat S C (stat_switch_nodefault_2 y1 vi rv ts scs) o ->
      red_stat S C (stat_switch_nodefault_1 vi rv ((switchclause_intro e ts)::scs)) o

  | red_stat_switch_nodefault_2 : forall S0 S C b vi v1 rv ts scs o,
      b = (strict_equality_test v1 vi) ->
      red_stat S C (stat_switch_nodefault_3 b vi rv ts scs) o ->
      red_stat S0 C (stat_switch_nodefault_2 (ret S v1) vi rv ts scs) o

  | red_stat_switch_nodefault_3_false : forall S C vi rv scs ts o,
      red_stat S C (stat_switch_nodefault_1 vi rv scs) o ->
      red_stat S C (stat_switch_nodefault_3 false vi rv ts scs) o

  | red_stat_switch_nodefault_3_true : forall S C ts o o1 scs vi rv,
      red_stat S C (stat_block ts) o1 ->
      red_stat S C (stat_switch_nodefault_4 o1 scs) o ->
      red_stat S C (stat_switch_nodefault_3 true vi rv ts scs) o

  | red_stat_switch_nodefault_4 : forall S0 S C rv scs o,
      red_stat S C (stat_switch_nodefault_5 rv scs) o ->
      red_stat S0 C (stat_switch_nodefault_4 (out_ter S rv) scs) o

  | red_stat_switch_nodefault_5_nil : forall S C rv,
      red_stat S C (stat_switch_nodefault_5 rv nil) (out_ter S rv)

  | red_stat_switch_nodefault_5_cons : forall S C ts o o1 scs rv e,
      red_stat S C (stat_block ts) o1 ->
      red_stat S C (stat_switch_nodefault_6 rv o1 scs) o ->
      red_stat S C (stat_switch_nodefault_5 rv ((switchclause_intro e ts)::scs)) o

  | red_stat_switch_nodefault_6_normal : forall S0 S C R rv rv' scs o,
      rv' = (If (res_value R <> resvalue_empty) then (res_value R) else rv) ->
      red_stat S C (stat_switch_nodefault_5 rv' scs) o ->
      red_stat S0 C (stat_switch_nodefault_6 rv (out_ter S R) scs) o

  | red_stat_switch_nodefault_6_abrupt : forall S S0 C R R' scs rv,
      ~ res_is_normal R ->
      res_type R <> restype_throw -> (* TODO:  Added, but please reread, and eventually change [abort_intercepted_stat] to match this. *)
      R' = (res_overwrite_value_if_empty rv R) ->
      red_stat S0 C (stat_switch_nodefault_6 rv (out_ter S R) scs) (out_ter S R')

  (** -- Switch with default case *)

  (** ----- Switch with default case: search A *)

  | red_stat_switch_default_A_1_nil_true : forall S C vi rv ts1 scs2 o,
      (*red_stat S C (stat_switch_default_B_1 vi rv ts1 scs2) o ->*)
      red_stat S C (stat_switch_default_5 vi rv ts1 scs2) o ->
      red_stat S C (stat_switch_default_A_1 true vi rv nil ts1 scs2) o

  | red_stat_switch_default_A_1_nil_false : forall S C vi rv ts1 scs2 o,
      (*red_stat S C (stat_switch_default_5 vi rv ts1 scs2) o ->  *)
      red_stat S C (stat_switch_default_B_1 vi rv ts1 scs2) o ->
      red_stat S C (stat_switch_default_A_1 false vi rv nil ts1 scs2) o

  | red_stat_switch_default_A_1_cons_true : forall S C e o o1 vi rv ts ts1 scs scs2,
      red_stat S C (stat_switch_default_A_4 rv vi ts scs ts1 scs2) o ->
      red_stat S C (stat_switch_default_A_1 true vi rv ((switchclause_intro e ts)::scs) ts1 scs2) o

  | red_stat_switch_default_A_1_cons_false : forall S C e vi rv ts ts1 scs scs2 y1 o,
      red_spec S C (spec_expr_get_value e) y1 ->
      red_stat S C (stat_switch_default_A_2 y1 vi rv ts scs ts1 scs2) o ->
      red_stat S C (stat_switch_default_A_1 false vi rv ((switchclause_intro e ts)::scs) ts1 scs2) o

  | red_stat_switch_default_A_2 : forall S0 S C b vi v1 rv ts scs ts1 scs2 o,
      b = (strict_equality_test v1 vi) ->
      red_stat S C (stat_switch_default_A_3 b vi rv ts scs ts1 scs2) o ->
      red_stat S0 C (stat_switch_default_A_2 (ret S v1) vi rv ts scs ts1 scs2) o

  | red_stat_switch_default_A_3_false : forall S C vi rv scs ts ts1 scs2 o,
      red_stat S C (stat_switch_default_A_1 false vi rv scs ts1 scs2) o ->
      red_stat S C (stat_switch_default_A_3 false vi rv ts scs ts1 scs2) o

  | red_stat_switch_default_A_3_true : forall S C vi rv scs ts ts1 scs2 o,
      red_stat S C (stat_switch_default_A_4 rv vi ts scs ts1 scs2) o ->
      red_stat S C (stat_switch_default_A_3 true vi rv ts scs ts1 scs2) o

  | red_stat_switch_default_A_4 : forall S C o1 rv ts scs ts1 scs2 o vi,
      red_stat S C (stat_block ts) o1 ->
      red_stat S C (stat_switch_default_A_5 rv o1 vi scs ts1 scs2) o ->
      red_stat S C (stat_switch_default_A_4 rv vi ts scs ts1 scs2) o

  | red_stat_switch_default_A_5 : forall S S0 C vi rv0 rv rv' scs scs2 ts1 o,
      rv' = (If rv <> resvalue_empty then rv else rv0) -> (* TODO:  Added following a point of Section 12.11 of ECMA.  Please reread. *)
      red_stat S C (stat_switch_default_A_1 true vi rv' scs ts1 scs2) o ->
      red_stat S0 C (stat_switch_default_A_5 rv0 (out_ter S rv) vi scs ts1 scs2) o

  | red_stat_switch_default_A_5_abrupt : forall S S0 C vi rv R scs scs2 ts1 o, (* TODO:  Reread this rule! *)
      ~ res_is_normal R ->
      res_type R <> restype_throw -> (* TODO:  Added, but please reread, and eventually change [abort_intercepted_stat] to match this. *)
      red_stat S0 C (stat_switch_default_A_5 rv (out_ter S R) vi scs ts1 scs2) (out_ter S (res_overwrite_value_if_empty rv R))

  (** ----- Switch with default case: search B *)

  | red_stat_switch_default_B_1_nil : forall S C vi rv ts1 o,
      red_stat S C (stat_switch_default_5 vi rv ts1 nil) o ->
      red_stat S C (stat_switch_default_B_1 vi rv ts1 nil) o

  | red_stat_switch_default_B_1_cons : forall S C e o vi rv ts ts1 scs y1,
      red_spec S C (spec_expr_get_value e) y1 ->
      red_stat S C (stat_switch_default_B_2 y1 vi rv ts ts1 scs) o ->
      red_stat S C (stat_switch_default_B_1 vi rv ts1 ((switchclause_intro e ts)::scs)) o

  | red_stat_switch_default_B_2 : forall S S0 C b vi v1 rv ts scs ts1 o,
      b = (strict_equality_test v1 vi) ->
      red_stat S C (stat_switch_default_B_3 b vi rv ts ts1 scs) o ->
      red_stat S0 C (stat_switch_default_B_2 (ret S v1) vi rv ts ts1 scs) o

  | red_stat_switch_default_B_3_false : forall S C vi rv scs ts ts1 o,
      red_stat S C (stat_switch_default_B_1 vi rv ts1 scs) o ->
      red_stat S C (stat_switch_default_B_3 false vi rv ts ts1 scs) o

  | red_stat_switch_default_B_3_true : forall S C o1 rv ts scs ts1 o vi,
      red_stat S C (stat_block ts) o1 ->
      red_stat S C (stat_switch_default_B_4 o1 ts1 scs) o ->
      red_stat S C (stat_switch_default_B_3 true vi rv ts ts1 scs) o

  | red_stat_switch_default_B_4 : forall S S0 C rv scs ts1 o,
      red_stat S C (stat_switch_default_7 rv scs) o ->
      red_stat S0 C (stat_switch_default_B_4 (out_ter S rv) ts1 scs) o

  (** ----- Switch with default case: default *)

  | red_stat_switch_default_5 : forall S C o o1 ts vi rv scs,
      red_stat S C (stat_block ts) o1 ->
      red_stat S C (stat_switch_default_6 o1 scs) o ->
      red_stat S C (stat_switch_default_5 vi rv ts scs) o (* TODO:  What is the use of this [vi] and [rv]?  Can't we remove them? *)

  | red_stat_switch_default_6 : forall S S0 C o rv scs,
      red_stat S C (stat_switch_default_7 rv scs) o ->
      red_stat S0 C (stat_switch_default_6 (out_ter S rv) scs) o

  (** ----- Switch with default case: end *)

  | red_stat_switch_default_7_nil : forall S C rv,
      red_stat S C (stat_switch_default_7 rv nil) (out_ter S rv)

  | red_stat_switch_default_7_cons : forall S C ts rv o o1 scs e,
      red_stat S C (stat_block ts) o1 ->
      red_stat S C (stat_switch_default_8 rv o1 scs) o ->
      red_stat S C (stat_switch_default_7 rv ((switchclause_intro e ts)::scs)) o

  | red_stat_switch_default_8_normal : forall S S0 C rv0 rv rv' scs o,
      rv' = (If rv <> resvalue_empty then rv else rv0) -> (* TODO:  Added following the point 9.b.ii of Section 12.11 of ECMA.  Please reread. *)
      red_stat S C (stat_switch_default_7 rv' scs) o ->
      red_stat S0 C (stat_switch_default_8 rv0 (out_ter S rv) scs) o

  | red_stat_switch_default_8_abrupt : forall S S0 C R scs rv,
      ~ res_is_normal R ->
      res_type R <> restype_throw -> (* TODO:  Added, but please reread, and eventually change [abort_intercepted_stat] to match this. *)
      red_stat S0 C (stat_switch_default_8 rv (out_ter S R) scs) (out_ter S (res_overwrite_value_if_empty rv R))

  (** Labelled statement (12.12)
      -- See also the definition of [abort_intercepted_stat]. *)

  | red_stat_label : forall S C slab t o1 o,
      red_stat S C t o1 ->
      red_stat S C (stat_label_1 (label_string slab) o1) o ->
      red_stat S C (stat_label slab t) o

  | red_stat_label_1_normal : forall S0 S lab C R,
      res_type R = restype_normal ->
      red_stat S0 C (stat_label_1 lab (out_ter S R)) (out_ter S R)

  | red_stat_label_1_break_eq : forall S0 S C R rv lab,
      R = res_intro restype_break rv lab ->
      red_stat S0 C (stat_label_1 lab (out_ter S R)) (out_ter S (res_normal rv))

 (** Throw statement (12.13) *)

  | red_stat_throw : forall S C e o y1,
      red_spec S C (spec_expr_get_value e) y1 ->
      red_stat S C (stat_throw_1 y1) o ->
      red_stat S C (stat_throw e) o

  | red_stat_throw_1 : forall S0 S C v,
      red_stat S0 C (stat_throw_1 (ret S v)) (out_ter S (res_throw v))

  (** Try statement (12.14)
      -- See also the definition of [abort_intercepted_stat]. *)

  | red_stat_try : forall S C t co fo o o1,
      red_stat S C t o1 ->
      red_stat S C (stat_try_1 o1 co fo) o ->
      red_stat S C (stat_try t co fo) o

  | red_stat_try_1_no_throw : forall S0 S C R co fo o,
      res_type R <> restype_throw ->
      red_stat S C (stat_try_4 R fo) o ->
      red_stat S0 C (stat_try_1 (out_ter S R) co fo) o

  | red_stat_try_1_throw_no_catch : forall S0 S C R fo o,
      res_type R = restype_throw ->
      red_stat S C (stat_try_4 R fo) o ->
      red_stat S0 C (stat_try_1 (out_ter S R) None fo) o

  | red_stat_try_1_throw_catch : forall v S0 S S' C lex lex' oldlex L x R t1 fo o1 o,
      res_type R = restype_throw ->
      lex = execution_ctx_lexical_env C ->
      (lex',S') = lexical_env_alloc_decl S lex ->
      lex' = L::oldlex -> (* Note: oldlex is in fact equal to lex *)
      res_value R = resvalue_value v ->
      red_expr S' C (spec_env_record_create_set_mutable_binding L x None v throw_irrelevant) o1 ->
      red_stat S' C (stat_try_2 o1 lex' t1 fo) o ->
      red_stat S0 C (stat_try_1 (out_ter S R) (Some (x,t1)) fo) o

  | red_stat_try_2_catch : forall C S0 S lex' t1 fo o o1,
      red_stat S (execution_ctx_with_lex C lex') t1 o1 ->
      red_stat S C (stat_try_3 o1 fo) o ->
      red_stat S0 C (stat_try_2 (out_void S) lex' t1 fo) o

  | red_stat_try_3_catch_result : forall S0 S C R fo o,
      red_stat S C (stat_try_4 R fo) o ->
      red_stat S0 C (stat_try_3 (out_ter S R) fo) o

  | red_stat_try_4_no_finally : forall S C R,
      red_stat S C (stat_try_4 R None) (out_ter S R)

  | red_stat_try_4_finally : forall S C R t1 o o1,
      red_stat S C t1 o1 ->
      red_stat S C (stat_try_5 R o1) o ->
      red_stat S C (stat_try_4 R (Some t1)) o

  | red_stat_try_5_finally_result : forall S0 S C R rv,
      red_stat S0 C (stat_try_5 R (out_ter S rv)) (out_ter S R)

  (** Debugger statement (12.15) *)

  | red_stat_debugger : forall S C,
      red_stat S C stat_debugger (out_ter S res_empty)


(**************************************************************)
(** ** Reduction rules for expressions (11) *)

with red_expr : state -> execution_ctx -> ext_expr -> out -> Prop :=

  (** Abort rule for expressions *)

  | red_expr_abort : forall S C exte o,
      out_of_ext_expr exte = Some o ->
      abort o ->
       ~ abort_intercepted_expr exte ->
      red_expr S C exte o

  (** This construct (11.1.1) *)

  | red_expr_this : forall S C v,
      v = execution_ctx_this_binding C ->
      red_expr S C expr_this (out_ter S v)

  (** Identifier (11.1.2) *)

  | red_expr_identifier : forall S C x y1 o,
      red_spec S C (spec_identifier_resolution C x) y1 ->
      red_expr S C (expr_identifier_1 y1) o ->
      red_expr S C (expr_identifier x) o

  | red_expr_identifier_1 : forall S0 S C r,
      red_expr S0 C (expr_identifier_1 (ret S r)) (out_ter S r)

  (** Literal (11.1.3) *)

  | red_expr_literal : forall S C i v,
      v = convert_literal_to_prim i ->
      red_expr S C (expr_literal i) (out_ter S v)

  (** Array initializer : LATER (11.1.4) *)

  (** Object initializer (11.1.5) *)

  | red_expr_object : forall S C pds o1 o,
      red_expr S C (spec_construct_prealloc prealloc_object nil) o1 ->
      red_expr S C (expr_object_0 o1 pds) o ->
      red_expr S C (expr_object pds) o

  | red_expr_object_0 : forall S0 S C l pds o,
      red_expr S C (expr_object_1 l pds) o ->
      red_expr S0 C (expr_object_0 (out_ter S l) pds) o

  | red_expr_object_1_nil : forall S C l,
      red_expr S C (expr_object_1 l nil) (out_ter S l)

  | red_expr_object_1_cons : forall S C x l pn pb pds o,
      x = string_of_propname pn ->
      red_expr S C (expr_object_2 l x pb pds) o ->
      red_expr S C (expr_object_1 l ((pn,pb)::pds)) o

  | red_expr_object_2_val : forall S C e l x pds y1 o,
      red_spec S C (spec_expr_get_value e) y1 ->
      red_expr S C (expr_object_3_val l x y1 pds) o ->
      red_expr S C (expr_object_2 l x (propbody_val e) pds) o

  | red_expr_object_3_val : forall S S0 C l x A v o pds,
      A = attributes_data_intro v true true true ->
      red_expr S C (expr_object_4 l x A pds) o ->
      red_expr S0 C (expr_object_3_val l x (ret S v) pds) o

  | red_expr_object_2_get : forall S C bd l x o o1 pds,
      red_expr S C (spec_create_new_function_in C nil bd) o1 ->
      red_expr S C (expr_object_3_get l x o1 pds) o ->
      red_expr S C (expr_object_2 l x (propbody_get bd) pds) o

  | red_expr_object_3_get : forall S S0 C A l x v pds o,
      A = attributes_accessor_intro v undef true true ->
      red_expr S C (expr_object_4 l x A pds) o ->
      red_expr S0 C (expr_object_3_get l x (out_ter S v) pds) o

  | red_expr_object_2_set : forall S C l x pds o o1 bd args,
      red_expr S C (spec_create_new_function_in C args bd) o1 ->
      red_expr S C (expr_object_3_set l x o1 pds) o ->
      red_expr S C (expr_object_2 l x (propbody_set args bd) pds) o

  | red_expr_object_3_set : forall S S0 C A l x v pds o,
      A = attributes_accessor_intro undef v true true ->
      red_expr S C (expr_object_4 l x A pds) o ->
      red_expr S0 C (expr_object_3_set l x (out_ter S v) pds) o

  | red_expr_object_4 : forall S C A l x pds o o1,
      red_expr S C (spec_object_define_own_prop l x A false) o1 ->
      red_expr S C (expr_object_5 l pds o1) o ->
      red_expr S C (expr_object_4 l x A pds) o

  | red_expr_object_5 : forall S S0 C rv l pds o,
      red_expr S C (expr_object_1 l pds) o ->
      red_expr S0 C (expr_object_5 l pds (out_ter S rv)) o

  (** Member (11.2.1) *)

  | red_expr_member : forall x S0 C e1 o,
      red_expr S0 C (expr_access e1 (expr_literal (literal_string x))) o ->
      red_expr S0 C (expr_member e1 x) o

  (** Access (11.2.1) *)

  | red_expr_access : forall S C e1 e2 y1 o,
      red_spec S C (spec_expr_get_value e1) y1 ->
      red_expr S C (expr_access_1 y1 e2) o ->
      red_expr S C (expr_access e1 e2) o

  | red_expr_access_1 : forall S0 S C v1 e2 y1 o,
      red_spec S C (spec_expr_get_value e2) y1 ->
      red_expr S C (expr_access_2 v1 y1) o ->
      red_expr S0 C (expr_access_1 (ret S v1) e2) o

  | red_expr_access_2 : forall S0 S C v1 v2 o1 o,
      red_expr S C (spec_check_object_coercible v1) o1 ->
      red_expr S C (expr_access_3 v1 o1 v2) o ->
      red_expr S0 C (expr_access_2 v1 (ret S v2)) o

  | red_expr_access_3 : forall S0 S C v1 v2 o1 o,
      red_expr S C (spec_to_string v2) o1 ->
      red_expr S C (expr_access_4 v1 o1) o ->
      red_expr S0 C (expr_access_3 v1 (out_void S) v2) o

  | red_expr_access_4 : forall S0 S C v1 x r,
     r = ref_create_value v1 x (execution_ctx_strict C) ->
     red_expr S0 C (expr_access_4 v1 (out_ter S x)) (out_ter S r)

  (** New (11.2.2, second part) *)

  | red_expr_new : forall S C e1 e2s y1 o, (* Steps 1-2 *)
      red_spec S C (spec_expr_get_value e1) y1 ->
      red_expr S C (expr_new_1 y1 e2s) o ->
      red_expr S C (expr_new e1 e2s) o

  | red_expr_new_1 : forall S0 S C e2s v y1 o, (* Step 3 *)
      red_spec S C (spec_list_expr e2s) y1 ->
      red_expr S C (expr_new_2 v y1) o ->
      red_expr S0 C (expr_new_1 (ret S v) e2s) o

  | red_expr_new_2_type_error_not_object : forall S S0 C o v vs, (* Step 4 *)
      type_of v <> type_object ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S0 C (expr_new_2 v (ret S vs)) o

  | red_expr_new_2_type_error_no_construct : forall S S0 C o l vs, (* Step 5 *)
      object_method object_construct_ S l None ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S0 C (expr_new_2 (value_object l) (ret S vs)) o

  | red_expr_new_2_construct : forall S S0 C l vs o, (* Step 6 *)
      red_expr S C (spec_construct l vs) o ->
      red_expr S0 C (expr_new_2 (value_object l) (ret S vs)) o

  (** Call (11.2.3) *)

  | red_expr_call : forall S C e1 e2s o1 o2,
      red_expr S C e1 o1 ->
      red_expr S C (expr_call_1 o1 (is_syntactic_eval e1) e2s) o2 ->
      red_expr S C (expr_call e1 e2s) o2

  | red_expr_call_1 : forall S0 S C rv is_eval_direct e2s y1 o, (* Step 2 *)
      red_spec S C (spec_get_value rv) y1 ->
      red_expr S C (expr_call_2 rv is_eval_direct e2s y1) o ->
      red_expr S0 C (expr_call_1 (out_ter S rv) is_eval_direct e2s) o

  | red_expr_call_2 : forall S0 S C rv v e2s is_eval_direct y1 o, (* Step 3 *)
      red_spec S C (spec_list_expr e2s) y1 ->
      red_expr S C (expr_call_3 rv v is_eval_direct y1) o ->
      red_expr S0 C (expr_call_2 rv is_eval_direct e2s (ret S v)) o

  | red_expr_call_3 : forall S0 S C o rv v is_eval_direct vs, (* Steps 4-5 *)
      (type_of v <> type_object) \/ (exists l, v = value_object l /\ ~ is_callable S l) ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S0 C (expr_call_3 rv v is_eval_direct (ret S vs)) o

  | red_expr_call_3_callable : forall l S0 S C o rv is_eval_direct vs, (* Step 5 else *)
      is_callable S l ->
      red_expr S C (expr_call_4 rv l is_eval_direct vs) o ->
      red_expr S0 C (expr_call_3 rv (value_object l) is_eval_direct (ret S vs)) o

  | red_expr_call_4_prop : forall v S C o r l is_eval_direct vs, (* Step 6a *)
      ref_is_property r ->
      ref_is_value r v ->
      red_expr S C (expr_call_5 l is_eval_direct vs (out_ter S v)) o ->
      red_expr S C (expr_call_4 (resvalue_ref r) l is_eval_direct vs) o

  | red_expr_call_4_env : forall L o1 S C o r l is_eval_direct vs, (* Step 6b *)
      ref_is_env_record r L ->
      red_expr S C (spec_env_record_implicit_this_value L) o1 ->
      red_expr S C (expr_call_5 l is_eval_direct vs o1) o ->
      red_expr S C (expr_call_4 (resvalue_ref r) l is_eval_direct vs) o

  | red_expr_call_4_not_ref : forall S C v l is_eval_direct vs o, (* Step 7 *)
      red_expr S C (expr_call_5  l is_eval_direct vs (out_ter S undef)) o ->
      red_expr S C (expr_call_4 (resvalue_value v) l is_eval_direct vs) o

  | red_expr_call_5_eval : forall S0 S C vs v o, (* Step 8, special for eval *)
      red_expr S C (spec_call_global_eval true vs) o ->
      red_expr S0 C (expr_call_5 prealloc_global_eval true vs (out_ter S v)) o

   | red_expr_call_5_not_eval : forall S0 S C l is_eval_direct vs v o, (* Step 8 *)
      l <> prealloc_global_eval \/ !is_eval_direct ->
      red_expr S C (spec_call l v vs) o ->
      red_expr S0 C (expr_call_5 l is_eval_direct vs (out_ter S v)) o

  (** Function expression (11.2.5, 13) *)

  | red_expr_function_unnamed : forall S C args bd lex o,
      lex = execution_ctx_lexical_env C ->
      red_expr S C (spec_creating_function_object args bd lex (funcbody_is_strict bd)) o ->
      red_expr S C (expr_function None args bd) o

  | red_expr_function_named : forall lex' S' L lextail E o1 S C s args bd o,
      (lex', S') = lexical_env_alloc_decl S (execution_ctx_lexical_env C) ->
      lex' = L :: lextail ->
      env_record_binds S' L E ->
      red_expr S' C (spec_env_record_create_immutable_binding L s) o1 ->
      red_expr S' C (expr_function_1 s args bd L lex' o1) o ->
      red_expr S C (expr_function (Some s) args bd) o

  | red_expr_function_named_1 : forall o1 S0 S C s args bd L scope o,
      red_expr S C (spec_creating_function_object args bd scope (funcbody_is_strict bd)) o1 ->
      red_expr S C (expr_function_2 s L o1) o ->
      red_expr S0 C (expr_function_1 s args bd L scope (out_void S)) o

  | red_expr_function_named_2 : forall o1 S0 S C s L l o,
      red_expr S C (spec_env_record_initialize_immutable_binding L s l) o1 ->
      red_expr S C (expr_function_3 l o1) o ->
      red_expr S0 C (expr_function_2 s L (out_ter S l)) o

  | red_expr_function_named_3 : forall S0 S C l,
      red_expr S0 C (expr_function_3 l (out_void S)) (out_ter S l)

  (** Unary op : pre/post incr/decr (11.4) *)

  | red_expr_prepost : forall S C op e o1 o,
      prepost_unary_op op ->
      red_expr S C e o1 ->
      red_expr S C (expr_prepost_1 op o1) o ->
      red_expr S C (expr_unary_op op e) o

  | red_expr_prepost_1_valid : forall S0 S C rv op y1 o,
      red_spec S C (spec_get_value rv) y1 ->
      red_expr S C (expr_prepost_2 op rv y1) o ->
      red_expr S0 C (expr_prepost_1 op (out_ter S rv)) o

  | red_expr_prepost_2 : forall S0 S C rv op v o1 o,
      red_expr S C (spec_to_number v) o1 ->
      red_expr S C (expr_prepost_3 op rv o1) o ->
      red_expr S0 C (expr_prepost_2 op rv (ret S v)) o

  | red_expr_prepost_3 : forall S0 S C rv op number_op is_pre v n1 n2 o1 o,
      prepost_op op number_op is_pre ->
      n2 = number_op n1 ->
      v = prim_number (if is_pre then n2 else n1) ->
      red_expr S C (spec_put_value rv n2) o1 ->
      red_expr S C (expr_prepost_4 v o1) o ->
      red_expr S0 C (expr_prepost_3 op rv (out_ter S n1)) o

  | red_expr_prepost_4 : forall S0 S C v,
      red_expr S0 C (expr_prepost_4 v (out_void S)) (out_ter S v)

  (** Unary op -- common rules for regular operators *)

  | red_expr_unary_op : forall S C op e y1 o,
      regular_unary_op op ->
      red_spec S C (spec_expr_get_value e) y1 ->
      red_expr S C (expr_unary_op_1 op y1) o ->
      red_expr S C (expr_unary_op op e) o

  | red_expr_unary_op_1 : forall S0 S C op v o,
      red_expr S C (expr_unary_op_2 op v) o ->
      red_expr S0 C (expr_unary_op_1 op (ret S v)) o

  (** Unary op : delete (not a regular op) (11.4.1) *)

  | red_expr_delete : forall S C e o1 o,
      red_expr S C e o1 ->
      red_expr S C (expr_delete_1 o1) o ->
      red_expr S C (expr_unary_op unary_op_delete e) o

  | red_expr_delete_1_not_ref : forall S0 S C rv,
      ~ (resvalue_is_ref rv) ->
      red_expr S0 C (expr_delete_1 (out_ter S rv)) (out_ter S true)

  | red_expr_delete_1_ref_unresolvable : forall S0 S C r o,
      ref_is_unresolvable r ->
      red_expr S C (expr_delete_2 r) o ->
      red_expr S0 C (expr_delete_1 (out_ter S r)) o

  | red_expr_delete_2_strict : forall S C r o,
      ref_strict r = true ->
      red_expr S C (spec_error native_error_syntax) o ->
      red_expr S C (expr_delete_2 r) o

  | red_expr_delete_2_not_strict : forall S C r,
      ref_strict r = false ->
      red_expr S C (expr_delete_2 r) (out_ter S true)

  | red_expr_delete_1_ref_property : forall S0 S C r v o1 o,
      ref_is_property r ->
      ref_base r = ref_base_type_value v ->
      red_expr S C (spec_to_object v) o1 ->
      red_expr S C (expr_delete_3 r o1) o ->
      red_expr S0 C (expr_delete_1 (out_ter S r)) o

  | red_expr_delete_3 : forall S0 S C r l o,
      red_expr S C (spec_object_delete l (ref_name r) (ref_strict r)) o ->
      red_expr S0 C (expr_delete_3 r (out_ter S l)) o

  | red_expr_delete_1_ref_env_record : forall S0 S C r L o,
      ref_is_env_record r L ->
      red_expr S C (expr_delete_4 r L) o ->
      red_expr S0 C (expr_delete_1 (out_ter S r)) o

  | red_expr_delete_4_strict : forall S C r L o,
      ref_strict r = true ->
      red_expr S C (spec_error native_error_syntax) o ->
      red_expr S C (expr_delete_4 r L) o

  | red_expr_delete_4_not_strict : forall S C r L o,
      ref_strict r = false ->
      red_expr S C (spec_env_record_delete_binding L (ref_name r)) o ->
      red_expr S C (expr_delete_4 r L) o

  (** Unary op : void  (11.4.2)*)

  | red_expr_unary_op_void : forall S C v,
      red_expr S C (expr_unary_op_2 unary_op_void v) (out_ter S undef)

  (** Unary op : typeof (not a regular op) (11.4.3) *)

  | red_expr_typeof : forall S C e o1 o,
      red_expr S C e o1 ->
      red_expr S C (expr_typeof_1 o1) o ->
      red_expr S C (expr_unary_op unary_op_typeof e) o

  | red_expr_typeof_1_value : forall S0 S C v o,
      red_expr S C (expr_typeof_2 (ret S v)) o ->
      red_expr S0 C (expr_typeof_1 (out_ter S v)) o

  | red_expr_typeof_1_ref_unresolvable : forall S0 S r C,
      ref_is_unresolvable r ->
      red_expr S0 C (expr_typeof_1 (out_ter S r)) (out_ter S "undefined")

  | red_expr_typeof_1_ref_resolvable : forall S0 S C r y1 o,
      ~ (ref_is_unresolvable r) ->
      red_spec S C (spec_get_value r) y1 ->
      red_expr S C (expr_typeof_2 y1) o ->
      red_expr S0 C (expr_typeof_1 (out_ter S r)) o

  | red_expr_typeof_2 : forall S0 S s C v,
      s = typeof_value S v ->
      red_expr S0 C (expr_typeof_2 (ret S v)) (out_ter S s)

  (** Unary op : add (11.4.6) *)

  | red_expr_unary_op_add : forall S C v o,
      red_expr S C (spec_to_number v) o ->
      red_expr S C (expr_unary_op_2 unary_op_add v) o

  (** Unary op : neg (11.4.7) *)

  | red_expr_unary_op_neg : forall S C v o1 o,
      red_expr S C (spec_to_number v) o1 ->
      red_expr S C (expr_unary_op_neg_1 o1) o ->
      red_expr S C (expr_unary_op_2 unary_op_neg v) o

  | red_expr_unary_op_neg_1 : forall S0 S C n,
      red_expr S0 C (expr_unary_op_neg_1 (out_ter S n)) (out_ter S (JsNumber.neg n))

  (** Unary op : bitwise not (11.4.8) *)

  | red_expr_unary_op_bitwise_not : forall S C v y1 o,
      red_spec S C (spec_to_int32 v) y1 ->
      red_expr S C (expr_unary_op_bitwise_not_1 y1) o ->
      red_expr S C (expr_unary_op_2 unary_op_bitwise_not v) o

  | red_expr_unary_op_bitwise_not_1 : forall S0 S C k n,
      n = JsNumber.of_int (JsNumber.int32_bitwise_not k) ->
      red_expr S0 C (expr_unary_op_bitwise_not_1 (ret S k)) (out_ter S n)

  (** Unary op : not (11.4.9) *)

  | red_expr_unary_op_not : forall S C v o1 o,
      red_expr S C (spec_to_boolean v) o1 ->
      red_expr S C (expr_unary_op_not_1 o1) o ->
      red_expr S C (expr_unary_op_2 unary_op_not v) o

  | red_expr_unary_op_not_1 : forall S0 S C b,
      red_expr S0 C (expr_unary_op_not_1 (out_ter S b)) (out_ter S (neg b))

  (** Binary op -- common rules for regular operators *)

  | red_expr_binary_op : forall S C op e1 e2 y1 o ,
      regular_binary_op op ->
      red_spec S C (spec_expr_get_value e1) y1 ->
      red_expr S C (expr_binary_op_1 op y1 e2) o ->
      red_expr S C (expr_binary_op e1 op e2) o

  | red_expr_binary_op_1 : forall S0 S C op v1 e2 y1 o,
      red_spec S C (spec_expr_get_value e2) y1 ->
      red_expr S C (expr_binary_op_2 op v1 y1) o ->
      red_expr S0 C (expr_binary_op_1 op (ret S v1) e2) o

  | red_expr_binary_op_2 : forall S0 S C op v1 v2 o,
      red_expr S C (expr_binary_op_3 op v1 v2) o ->
      red_expr S0 C (expr_binary_op_2 op v1 (ret S v2)) o

  (** Binary op : addition (11.6.1) *)

  | red_expr_binary_op_add : forall S C v1 v2 y1 o,
      red_spec S C (spec_convert_twice (spec_to_primitive_auto v1) (spec_to_primitive_auto v2)) y1 ->
      red_expr S C (expr_binary_op_add_1 y1) o ->
      red_expr S C (expr_binary_op_3 binary_op_add v1 v2) o

  | red_expr_binary_op_add_1_string : forall S0 S C v1 v2 y1 o,
      (type_of v1 = type_string \/ type_of v2 = type_string) ->
      red_spec S C (spec_convert_twice (spec_to_string v1) (spec_to_string v2)) y1 ->
      red_expr S C (expr_binary_op_add_string_1 y1) o ->
      red_expr S0 C (expr_binary_op_add_1 (ret S (v1,v2))) o

  | red_expr_binary_op_add_string_1 : forall S0 S C s1 s2 s,
      s = String.append s1 s2 ->
      red_expr S0 C (expr_binary_op_add_string_1 (ret S (value_prim s1, value_prim s2))) (out_ter S s)

  | red_expr_binary_op_add_1_number : forall S0 S C v1 v2 y1 o,
      ~ (type_of v1 = type_string \/ type_of v2 = type_string) ->
      red_spec S C (spec_convert_twice (spec_to_number v1) (spec_to_number v2)) y1 ->
      red_expr S C (expr_puremath_op_1 JsNumber.add y1) o ->
      (* LATER: maybe we could go more directly to "expr_binary_op_3 JsNumber.add" *)
      red_expr S0 C (expr_binary_op_add_1 (ret S (v1,v2))) o

  (** Binary op : pure maths operations (11.5) *)

  | red_expr_puremath_op : forall S C op F v1 v2 y1 o,
      puremath_op op F ->
      red_spec S C (spec_convert_twice (spec_to_number v1) (spec_to_number v2)) y1 ->
      red_expr S C (expr_puremath_op_1 F y1) o ->
      red_expr S C (expr_binary_op_3 op v1 v2) o

  | red_expr_puremath_op_1 : forall S0 S C F n n1 n2,
      n = F n1 n2 ->
      red_expr S0 C (expr_puremath_op_1 F (ret S (value_prim n1, value_prim n2))) (out_ter S n)

  (** Binary op : shift operations (11.7) *)

  | red_expr_shift_op : forall b_unsigned S C op  F ext v1 v2 y1 o,
      shift_op op b_unsigned F ->
      ext = (if b_unsigned then spec_to_uint32 else spec_to_int32) ->
      red_spec S C (ext v1) y1 ->
      red_expr S C (expr_shift_op_1 F y1 v2) o ->
      red_expr S C (expr_binary_op_3 op v1 v2) o

  | red_expr_shift_op_1 : forall S0 S C F k1 v2 y1 o,
      red_spec S C (spec_to_uint32 v2) y1 ->
      red_expr S C (expr_shift_op_2 F k1 y1) o ->
      red_expr S0 C (expr_shift_op_1 F (ret S k1) v2) o

  | red_expr_shift_op_2 : forall S0 S C k1 k2 F n,
      n = JsNumber.of_int (F k1 (JsNumber.modulo_32 k2)) ->
      red_expr S0 C (expr_shift_op_2 F k1 (ret S k2)) (out_ter S n)

  (** Binary op : inequality (11.8) *)

  | red_expr_inequality_op : forall S C v1 v2 op b_swap b_neg o,
      inequality_op op b_swap b_neg ->
      red_expr S C (expr_inequality_op_1 b_swap b_neg v1 v2) o ->
      red_expr S C (expr_binary_op_3 op v1 v2) o

  | red_expr_inequality_op_1 : forall S C v1 v2 b_swap b_neg y1 o,
      red_spec S C (spec_convert_twice (spec_to_primitive_auto v1) (spec_to_primitive_auto v2)) y1 ->
      red_expr S C (expr_inequality_op_2 b_swap b_neg y1) o ->
      red_expr S C (expr_inequality_op_1 b_swap b_neg v1 v2) o

  | red_expr_inequality_op_2 : forall S0 S C (w1 w2 wa wb wr wr':prim) (b_swap b_neg : bool),
      ((wa,wb) = if b_swap then (w2,w1) else (w1,w2)) ->
      wr = inequality_test_primitive wa wb ->
      (* Note: wr may only be true or false or undef *)
      wr' = (If wr = prim_undef then false
            else If (b_neg = true /\ wr = true) then false
            else If (b_neg = true /\ wr = false) then true
            else wr) ->
      red_expr S0 C (expr_inequality_op_2 b_swap b_neg (ret S (value_prim w1, value_prim w2))) (out_ter S wr')

  (** Binary op : instanceof (11.8.6) *)

  | red_expr_binary_op_instanceof_non_object : forall S C v1 v2 o,
      type_of v2 <> type_object ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (expr_binary_op_3 binary_op_instanceof v1 v2) o

  | red_expr_binary_op_instanceof_non_instance : forall S C v1 l o,
      object_method object_has_instance_ S l None ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (expr_binary_op_3 binary_op_instanceof v1 (value_object l)) o

  | red_expr_binary_op_instanceof_normal : forall S C v1 l o,
      red_expr S C (spec_object_has_instance l v1) o ->
      red_expr S C (expr_binary_op_3 binary_op_instanceof v1 (value_object l)) o

  (** Binary op : in (11.8.7) *)

  | red_expr_binary_op_in_non_object : forall S C v1 v2 o,
      type_of v2 <> type_object ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (expr_binary_op_3 binary_op_in v1 v2) o

  | red_expr_binary_op_in_object : forall S C v1 l o1 o,
      red_expr S C (spec_to_string v1) o1 ->
      red_expr S C (expr_binary_op_in_1 l o1) o ->
      red_expr S C (expr_binary_op_3 binary_op_in v1 (value_object l)) o

  | red_expr_binary_op_in_1 : forall S0 S C l x o,
      red_expr S C (spec_object_has_prop l x) o ->
      red_expr S0 C (expr_binary_op_in_1 l (out_ter S x)) o

  (** Binary op : equality/disequality (11.9) *)

  | red_expr_binary_op_equal : forall S C v1 v2 o,
      red_expr S C (spec_equal v1 v2) o ->
      red_expr S C (expr_binary_op_3 binary_op_equal v1 v2) o

  | red_expr_binary_op_disequal : forall S C v1 v2 o1 o,
      red_expr S C (spec_equal v1 v2) o1 ->
      red_expr S C (expr_binary_op_disequal_1 o1) o ->
      red_expr S C (expr_binary_op_3 binary_op_disequal v1 v2) o

  | red_expr_binary_op_disequal_1 : forall S0 S C b,
      red_expr S0 C (expr_binary_op_disequal_1 (out_ter S b)) (out_ter S (negb b))

  (** Binary op : conversion steps for the abstract equality algorithm (11.9.3) *)

  | red_spec_equal : forall S C v1 v2 ty1 ty2 o,
      ty1 = type_of v1 ->
      ty2 = type_of v2 ->
      red_expr S C (spec_equal_1 ty1 ty2 v1 v2) o ->
      red_expr S C (spec_equal v1 v2) o

  | red_spec_equal_1_same_type : forall S C v1 v2 ty b,
      b = equality_test_for_same_type ty v1 v2 ->
      red_expr S C (spec_equal_1 ty ty v1 v2) (out_ter S b)

  | red_spec_equal_1_diff_type : forall S C v1 v2 ty1 ty2 ext o,
      ext =
        (If ty1 = type_null /\ ty2 = type_undef then (spec_equal_2 true)
        else If ty1 = type_undef /\ ty2 = type_null then (spec_equal_2 true)
        else If ty1 = type_number /\ ty2 = type_string then (spec_equal_3 v1 spec_to_number v2)
        else If ty1 = type_string /\ ty2 = type_number then (spec_equal_3 v2 spec_to_number v1)
        else If ty1 = type_bool then (spec_equal_3 v2 spec_to_number v1)
        else If ty2 = type_bool then (spec_equal_3 v1 spec_to_number v2)
        else If (ty1 = type_string \/ ty1 = type_number) /\ ty2 = type_object then (spec_equal_3 v1 spec_to_primitive_auto v2)
        else If ty1 = type_object /\ (ty2 = type_string \/ ty2 = type_number) then (spec_equal_3 v2 spec_to_primitive_auto v1)
        else (spec_equal_2 false)) ->
      red_expr S C ext o ->
      red_expr S C (spec_equal_1 ty1 ty2 v1 v2) o

  | red_spec_equal_2_return : forall S C b,
      red_expr S C (spec_equal_2 b) (out_ter S b)

  | red_spec_equal_3_convert_and_recurse : forall S C v1 v2 K o2 o,
      red_expr S C (K v2) o2 ->
      red_expr S C (spec_equal_4 v1 o2) o ->
      red_expr S C (spec_equal_3 v1 K v2) o

  | red_spec_equal_4_recurse : forall S0 S C v1 v2 o,
      red_expr S C (spec_equal v1 v2) o ->
      red_expr S0 C (spec_equal_4 v1 (out_ter S v2)) o

  (** Binary op : strict equality/disequality (11.9.4) *)

  | red_expr_binary_op_strict_equal : forall S C v1 v2 b,
      b = strict_equality_test v1 v2 ->
      red_expr S C (expr_binary_op_3 binary_op_strict_equal v1 v2) (out_ter S b)

  | red_expr_binary_op_strict_disequal : forall S C v1 v2 b,
      b = negb (strict_equality_test v1 v2) ->
      red_expr S C (expr_binary_op_3 binary_op_strict_disequal v1 v2) (out_ter S b)

  (** Binary op : bitwise op (11.10) *)

  | red_expr_bitwise_op : forall S C op F v1 v2 y1 o,
      bitwise_op op F ->
      red_spec S C (spec_to_int32 v1) y1 ->
      red_expr S C (expr_bitwise_op_1 F y1 v2) o ->
      red_expr S C (expr_binary_op_3 op v1 v2) o

  | red_expr_bitwise_op_1 : forall S0 S C F k1 v2 y1 o,
      red_spec S C (spec_to_int32 v2) y1 ->
      red_expr S C (expr_bitwise_op_2 F k1 y1) o ->
      red_expr S0 C (expr_bitwise_op_1 F (ret S k1) v2) o

  | red_expr_bitwise_op_2 : forall S0 S C F k1 k2 n,
      n = JsNumber.of_int (F k1 k2) ->
      red_expr S0 C (expr_bitwise_op_2 F k1 (ret S k2)) (out_ter S n)

  (** Binary op : lazy ops [and] and [or] (not regular ops) (11.11) *)

  | red_expr_binary_op_lazy : forall S C op b_ret e1 e2 y1 o,
      lazy_op op b_ret ->
      red_spec S C (spec_expr_get_value e1) y1 ->
      red_expr S C (expr_lazy_op_1 b_ret y1 e2) o ->
      red_expr S C (expr_binary_op e1 op e2) o

  | red_expr_lazy_op_1 : forall S0 S C b_ret e2 v1 o1 o,
      red_expr S C (spec_to_boolean v1) o1 ->
      red_expr S C (expr_lazy_op_2 b_ret v1 o1 e2) o ->
      red_expr S0 C (expr_lazy_op_1 b_ret (ret S v1) e2) o

  | red_expr_lazy_op_2_first : forall S0 S C b_ret b1 e2 v1,
      b1 = b_ret ->
      red_expr S0 C (expr_lazy_op_2 b_ret v1 (out_ter S b1) e2) (out_ter S v1)

  | red_expr_lazy_op_2_second : forall S0 S C v1 b_ret b1 e2 y1 o,
      b1 <> b_ret ->
      red_spec S C (spec_expr_get_value e2) y1 ->
      red_expr S C (expr_lazy_op_2_1 y1) o ->
      red_expr S0 C (expr_lazy_op_2 b_ret v1 (out_ter S b1) e2) o

  | red_expr_lazy_op_2_second_1 : forall S0 S C v,
      red_expr S0 C (expr_lazy_op_2_1 (ret S v)) (out_ter S v)

  (** Conditional operator (11.12) *)

  | red_expr_conditional : forall S C e1 e2 e3 y1 o,
      red_spec S C (spec_expr_get_value_conv spec_to_boolean e1) y1 ->
      red_expr S C (expr_conditional_1 y1 e2 e3) o ->
      red_expr S C (expr_conditional e1 e2 e3) o

  | red_expr_conditional_1 : forall S0 S C e b e2 e3 y1 o,
      e = (If b = true then e2 else e3) ->
      red_spec S C (spec_expr_get_value e) y1 ->
      red_expr S C (expr_conditional_2 y1) o ->
      red_expr S0 C (expr_conditional_1 (vret S b) e2 e3) o

  | red_expr_conditional_2 : forall S0 S C v,
      red_expr S0 C (expr_conditional_2 (ret S v)) (out_ter S v)

  (** Assignment (11.13) *)

  | red_expr_assign : forall S C opo e1 e2 o o1,
      red_expr S C e1 o1 ->
      red_expr S C (expr_assign_1 o1 opo e2) o ->
      red_expr S C (expr_assign e1 opo e2) o

  | red_expr_assign_1_simple : forall S0 S C rv e2 y1 o,
      red_spec S C (spec_expr_get_value e2) y1 ->
      red_expr S C (expr_assign_4 rv y1) o ->
      red_expr S0 C (expr_assign_1 (out_ter S rv) None e2) o

  | red_expr_assign_1_compound : forall S0 S C rv op e2 y1 o,
      red_spec S C (spec_get_value rv) y1 ->
      red_expr S C (expr_assign_2 rv y1 op e2) o ->
      red_expr S0 C (expr_assign_1 (out_ter S rv) (Some op) e2) o

  | red_expr_assign_2_compound_get_value : forall S0 S C rv op v1 e2 y1 o,
      red_spec S C (spec_expr_get_value e2) y1 ->
      red_expr S C (expr_assign_3 rv v1 op y1) o ->
      red_expr S0 C (expr_assign_2 rv (ret S v1) op e2) o

  | red_expr_assign_3_compound_op : forall S0 S C rv op v1 v2 o1 o,
      red_expr S C (expr_binary_op_3 op v1 v2) o1 ->
      red_expr S C (expr_assign_3' rv o1) o ->
      red_expr S0 C (expr_assign_3 rv v1 op (ret S v2)) o

  | red_expr_assign_3': forall S0 S C v rv o,
      red_expr S C (expr_assign_4 rv (ret S v)) o ->
      red_expr S0 C (expr_assign_3' rv (out_ter S v)) o

  | red_expr_assign_4_put_value : forall S0 S C rv v o1 o,
      red_expr S C (spec_put_value rv v) o1 ->
      red_expr S C (expr_assign_5 v o1) o ->
      red_expr S0 C (expr_assign_4 rv (ret S v)) o

  | red_expr_assign_5_return : forall S0 S C rv' v,
      red_expr S0 C (expr_assign_5 v (out_ter S rv')) (out_ter S v)

  (** Coma (represented as a binary operator) (11.14) *)

  | red_expr_binary_op_coma : forall S C v1 v2,
      red_expr S C (expr_binary_op_3 binary_op_coma v1 v2) (out_ter S v2)


(**************************************************************)
(** ** Reduction rules for specification functions *)

  (** Special function *)

  (* LATER: see if useful *)
  | red_spec_returns : forall S C o,
      red_expr S C (spec_returns o) o


  (*------------------------------------------------------------*)
  (** ** Conversions (9) *)

  | red_spec_prim_new_object_bool : forall S C b S' l,
      let O1 := object_new prealloc_bool_proto "Boolean" in
      let O := object_with_primitive_value O1 b in
      (l, S') = object_alloc S O ->
      red_expr S C (spec_prim_new_object (prim_bool b)) (out_ter S' l)

  | red_spec_prim_new_object_number : forall S C n S' l,
      let O1 := object_new prealloc_number_proto "Number" in
      let O := object_with_primitive_value O1 n in
      (l, S') = object_alloc S O ->
      red_expr S C (spec_prim_new_object (prim_number n)) (out_ter S' l)

  | red_spec_prim_new_object_string : forall S C s S' S'' l,
      let O2 := object_new prealloc_string_proto "String" in
      let O1 := object_with_get_own_property O2 builtin_get_own_prop_string in
      let O := object_with_primitive_value O1 s in
      (l, S') = object_alloc S O ->
      object_set_property S' l "length" (attributes_data_intro_constant (JsNumber.of_int (String.length s))) S'' ->
      red_expr S C (spec_prim_new_object (prim_string s)) (out_ter S'' l)

  (** Conversion to primitive (returns prim) (9.1) *)

  | red_spec_to_primitive_pref_prim : forall S C w prefo,
      red_expr S C (spec_to_primitive (value_prim w) prefo) (out_ter S w)

  | red_spec_to_primitive_pref_object : forall S C l prefo o,
      red_expr S C (spec_object_default_value l prefo) o ->
      red_expr S C (spec_to_primitive (value_object l) prefo) o

  (** Conversion to bool (returns bool) (9.2) *)

  | red_spec_to_boolean : forall S C v b,
      b = convert_value_to_boolean v ->
      red_expr S C (spec_to_boolean v) (out_ter S b)

  (** Conversion to number (returns number) (9.3) *)

  | red_spec_to_number_prim : forall S C w n,
      n = convert_prim_to_number w ->
      red_expr S C (spec_to_number (value_prim w)) (out_ter S n)

  | red_spec_to_number_object : forall S C l o1 o,
      red_expr S C (spec_to_primitive (value_object l) (Some preftype_number)) o1 ->
      red_expr S C (spec_to_number_1 o1) o ->
      red_expr S C (spec_to_number (value_object l)) o

  | red_spec_to_number_1 : forall S0 S C w n,
      n = convert_prim_to_number w ->
      red_expr S0 C (spec_to_number_1 (out_ter S w)) (out_ter S n)

  (** Conversion to integer (returns number) (9.4) *)

  | red_spec_to_integer : forall S C v o1 o,
      red_expr S C (spec_to_number v) o1 ->
      red_expr S C (spec_to_integer_1 o1) o ->
      red_expr S C (spec_to_integer v) o

  | red_spec_to_integer_1 : forall S0 S C n n',
      n' = convert_number_to_integer n ->
      red_expr S0 C (spec_to_integer_1 (out_ter S n)) (out_ter S n')

  (** Conversion to string (returns string) (9.8) *)

  | red_spec_to_string_prim : forall S C w s,
      s = convert_prim_to_string w ->
      red_expr S C (spec_to_string (value_prim w)) (out_ter S s)

  | red_spec_to_string_object : forall S C l o1 o,
      red_expr S C (spec_to_primitive (value_object l) (Some preftype_string)) o1 ->
      red_expr S C (spec_to_string_1 o1) o ->
      red_expr S C (spec_to_string (value_object l)) o

  | red_spec_to_string_1 : forall S0 S C w s,
      s = convert_prim_to_string w ->
      red_expr S0 C (spec_to_string_1 (out_ter S w)) (out_ter S s)

  (** Conversion to object (returns object_loc) (9.9) *)

  | red_spec_to_object_undef_or_null : forall S C v o,
      v = prim_undef \/ v = prim_null ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (spec_to_object v) o

  | red_spec_to_object_prim : forall S C w o,
      ~ (w = prim_undef \/ w = prim_null) ->
      red_expr S C (spec_prim_new_object w) o ->
      red_expr S C (spec_to_object (value_prim w)) o

  | red_spec_to_object_object : forall S C l,
      red_expr S C (spec_to_object (value_object l)) (out_ter S l)

  (** Check object coercible (returns void) (9.10) *)

  | red_spec_check_object_coercible_undef_or_null : forall S C v o,
      v = prim_undef \/ v = prim_null ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (spec_check_object_coercible v) o

  | red_spec_check_object_coercible_return : forall S C v,
      ~ (v = prim_undef \/ v = prim_null) ->
      red_expr S C (spec_check_object_coercible v) (out_void S)

  (** IsCallable: is handled inline in the rules (9.11) *)


  (*------------------------------------------------------------*)
  (** ** Dispatch for operations on objects (8.6.2) *)

  (** Get (returns value) *)

  | red_spec_object_get : forall S C l x B o,
      object_method object_get_ S l B ->
      red_expr S C (spec_object_get_1 B l l x) o ->
      red_expr S C (spec_object_get l x) o

  (** Put (returns void) *)

  | red_spec_object_put : forall S C l x v throw B o,
      object_method object_put_ S l B ->
      (* LATER: Daiva: Double check [this] value *)
      red_expr S C (spec_object_put_1 B l l x v throw) o ->
      red_expr S C (spec_object_put l x v throw) o

  (** CanPut (returns bool) *)

  | red_spec_object_can_put : forall S C l x B o,
      object_method object_can_put_ S l B ->
      red_expr S C (spec_object_can_put_1 B l x) o ->
      red_expr S C (spec_object_can_put l x) o

  (** HasProperty (returns bool) *)

  | red_spec_object_has_prop : forall S C l x B o,
      object_method object_has_prop_ S l B ->
      red_expr S C (spec_object_has_prop_1 B l x) o ->
      red_expr S C (spec_object_has_prop l x) o

  (** Delete (returns bool) *)

  | red_spec_object_delete : forall S C l x throw B o,
      object_method object_delete_ S l B ->
      red_expr S C (spec_object_delete_1 B l x throw) o ->
      red_expr S C (spec_object_delete l x throw) o

  (** DefaultValue (returns value) *)

  | red_spec_object_default_value : forall S C l prefo B o,
      object_method object_default_value_ S l B ->
      red_expr S C (spec_object_default_value_1 B l prefo) o ->
      red_expr S C (spec_object_default_value l prefo) o

  (** DefineOwnProperty (returns bool) *)

  | red_spec_object_define_own_prop : forall S C l x Desc throw B o,
      object_method object_define_own_prop_ S l B ->
      red_expr S C (spec_object_define_own_prop_1 B l x Desc throw) o ->
      red_expr S C (spec_object_define_own_prop l x Desc throw) o

  (** HasInstance (returns bool) *)

  | red_spec_object_has_instance : forall S C l v B o,
      object_method object_has_instance_ S l (Some B) ->
      red_expr S C (spec_object_has_instance_1 B l v) o ->
      red_expr S C (spec_object_has_instance l v) o

  (** Function calls (returns value) *)

  | red_spec_call : forall S C l B this args o,
      object_method object_call_ S l (Some B) ->
      red_expr S C (spec_call_1 B l this args) o ->
      red_expr S C (spec_call l this args) o

  (** Constructor calls (returns value) *)

  (* LATER: rename to "red_spec_construct" *)
  | red_spec_constructor : forall S C l B args o,
      object_method object_construct_ S l (Some B) ->
      red_expr S C (spec_construct_1 B l args) o ->
      red_expr S C (spec_construct l args) o

  (** Shorthand: builtin function calls (returns value) *)

  | red_spec_call_1_prealloc : forall S C B lo this args o,
      red_expr S C (spec_call_prealloc B this args) o ->
      red_expr S C (spec_call_1 (call_prealloc B) lo this args) o

  (** Shorthand: builtin constructor calls (returns value) *)

  | red_spec_construct_1_prealloc : forall S C B l args o,
      red_expr S C (spec_construct_prealloc B args) o ->
      red_expr S C (spec_construct_1 (construct_prealloc B) l args) o


  (*------------------------------------------------------------*)
  (** ** Default implementations for operations on objects (8.12) *)

  (** Get (8.12.3) and (8.7.1)
      Note: rules are generalized so as to also handle the Put method on primitive values *)
  (* LATER: Maybe it'd be bettter not to factorize the two sets of rules...
           but copy-pasting is really ugly though.. *)

  | red_spec_object_get_1_default : forall S C vthis l x y1 o, (* Step 1 *)
      red_spec S C (spec_object_get_prop l x) y1 ->
      red_expr S C (spec_object_get_2 vthis y1) o ->
      red_expr S C (spec_object_get_1 builtin_get_default vthis l x) o

  | red_spec_object_get_2_undef : forall S0 S C vthis, (* Step 2 *)
      red_expr S0 C (spec_object_get_2 vthis (dret S full_descriptor_undef)) (out_ter S undef)

  | red_spec_object_get_2_data : forall S0 S C vthis Ad v, (* Step 3 *)
      v = attributes_data_value Ad ->
      red_expr S0 C (spec_object_get_2 vthis (dret S (attributes_data_of Ad))) (out_ter S v)

  | red_spec_object_get_2_accessor : forall S0 S C vthis Aa o, (* Step 4 *)
      red_expr S C (spec_object_get_3 vthis (attributes_accessor_get Aa)) o ->
      red_expr S0 C (spec_object_get_2 vthis (dret S (attributes_accessor_of Aa))) o

  |  red_spec_object_get_3_accessor_undef : forall S C vthis, (* Step 5 *)
      red_expr S C (spec_object_get_3 vthis undef) (out_ter S undef)

  | red_spec_object_get_3_accessor_object : forall S C vthis lf o, (* Step 6 *)
      red_expr S C (spec_call lf vthis nil) o ->
      red_expr S C (spec_object_get_3 vthis lf) o

  (** CanPut (8.12.4) *)

  | red_spec_object_can_put_1_default : forall S C l x o (y:specret full_descriptor), (* Step 1 *)
      red_spec S C (spec_object_get_own_prop l x) y ->
      red_expr S C (spec_object_can_put_2 l x y) o ->
      red_expr S C (spec_object_can_put_1 builtin_can_put_default l x) o

  | red_spec_object_can_put_2_accessor : forall S0 S C l x Aa b, (* Steps 2 and 2.a *)
      b = (If attributes_accessor_set Aa = undef then false else true) ->
      red_expr S C (spec_object_can_put_2 l x (ret (T:=full_descriptor) S0 (attributes_accessor_of Aa))) (out_ter S0 b)

  | red_spec_object_can_put_2_data : forall S0 S C l x Ad b, (* Step 2.b *)
      b = attributes_data_writable Ad ->
      red_expr S C (spec_object_can_put_2 l x (ret (T:=full_descriptor) S0 (attributes_data_of Ad))) (out_ter S0 b)

  | red_spec_object_can_put_2_undef : forall S0 S C l x o lproto, (* Step 3 *)
      object_proto S l lproto ->
      red_expr S C (spec_object_can_put_4 l x lproto) o ->
      red_expr S0 C (spec_object_can_put_2 l x (ret S full_descriptor_undef)) o

  | red_spec_object_can_put_4_null : forall S C l x b, (* Step 4 *)
      object_extensible S l b ->
      red_expr S C (spec_object_can_put_4 l x null) (out_ter S b)

  | red_spec_object_can_put_4_not_null : forall S C l x lproto y1 o, (* Step 5 *)
      red_spec S C (spec_object_get_prop lproto x) y1 ->
      red_expr S C (spec_object_can_put_5 l y1) o ->
      red_expr S C (spec_object_can_put_4 l x lproto) o

  | red_spec_object_can_put_5_undef : forall S0 S C l x b, (* Step 6 *)
      object_extensible S l b ->
      red_expr S0 C (spec_object_can_put_5 l (dret S full_descriptor_undef)) (out_ter S b)

  | red_spec_object_can_put_5_accessor : forall S0 S C l Aa b, (* Step 7 *)
      b = (If attributes_accessor_set Aa = undef then false else true) ->
      red_expr S0 C (spec_object_can_put_5 l (dret S (attributes_accessor_of Aa))) (out_ter S b)

  | red_spec_object_can_put_5_data : forall S0 S C l x Ad bext o, (* Step 8 *)
      object_extensible S l bext ->
      red_expr S C (spec_object_can_put_6 Ad bext) o ->
      red_expr S0 C (spec_object_can_put_5 l (dret S (attributes_data_of Ad))) o

  | red_spec_object_can_put_6_extens_false : forall S C Ad, (* Step 8.a *)
      red_expr S C (spec_object_can_put_6 Ad false) (out_ter S false)

  | red_spec_object_can_put_6_extens_true : forall S C Ad b, (* Step 8.b *)
      b = attributes_data_writable Ad ->
      red_expr S C (spec_object_can_put_6 Ad true) (out_ter S b)

  (** Put (8.12.5) and (8.7.2)
      Note: rules are generalized so as to also handle the Put method on primitive values *)

  | red_spec_object_put_1_default : forall S C vthis l x v throw o1 o, (* Step 1 *)
      red_expr S C (spec_object_can_put l x) o1 ->
      red_expr S C (spec_object_put_2 vthis l x v throw o1) o ->
      red_expr S C (spec_object_put_1 builtin_put_default vthis l x v throw) o

  | red_spec_object_put_2_false : forall S0 S C vthis l x v throw o, (* Steps 1.a and 1.b *)
      red_expr S C (spec_error_or_void throw native_error_type) o ->
      red_expr S0 C (spec_object_put_2 vthis l x v throw (out_ter S false)) o

  | red_spec_object_put_2_true : forall S0 S C vthis l x v throw o (y:specret full_descriptor), (* Step 2 *)
      red_spec S C (spec_object_get_own_prop l x) y ->
      red_expr S C (spec_object_put_3 vthis l x v throw y) o ->
      red_expr S0 C (spec_object_put_2 vthis l x v throw (out_ter S true)) o

  | red_spec_object_put_3_data_object : forall S0 S C (lthis:object_loc) l x v throw Ad Desc o1 o, (* Step 3 *)
      Desc = descriptor_intro (Some v) None None None None None ->
      red_expr S C (spec_object_define_own_prop l x Desc throw) o1 ->
      red_expr S C (spec_object_put_5 o1) o ->
      red_expr S0 C (spec_object_put_3 lthis l x v throw (ret (T:=full_descriptor) S (attributes_data_of Ad))) o

  | red_spec_object_put_3_data_prim : forall S0 S C (wthis:prim) l x v throw Ad o, (* Step 3, for prim values *)
      red_expr S C (spec_error_or_void throw native_error_type) o ->
      red_expr S0 C (spec_object_put_3 wthis l x v throw (ret (T:=full_descriptor) S (attributes_data_of Ad))) o

  | red_spec_object_put_3_not_data : forall S0 S C vthis l x v throw y1 o D, (* Step 4 *)
      (D = full_descriptor_undef) \/ (exists Aa, D = (attributes_accessor_of Aa)) ->
      red_spec S C (spec_object_get_prop l x) y1 ->
      red_expr S C (spec_object_put_4 vthis l x v throw y1) o ->
      red_expr S0 C (spec_object_put_3 vthis l x v throw (ret S D)) o

  | red_spec_object_put_4_accessor : forall S0 S C vsetter lfsetter vthis l x v throw Aa o1 o, (* Step 5 *)
      vsetter = attributes_accessor_set Aa ->
      vsetter <> undef -> (* Note: this premise is a derived fact *)
      vsetter = value_object lfsetter ->
      red_expr S C (spec_call lfsetter vthis (v::nil)) o1 ->
      red_expr S C (spec_object_put_5 o1) o ->
      red_expr S0 C (spec_object_put_4 vthis l x v throw (dret S (attributes_accessor_of Aa))) o

  | red_spec_object_put_4_not_accessor_object : forall S0 S C D (lthis:object_loc) l x v throw Ad Desc o1 o, (* Step 6 *)
      (D = full_descriptor_undef) \/  (D = (attributes_data_of Ad)) ->
      Desc = descriptor_intro_data v true true true ->
      red_expr S C (spec_object_define_own_prop l x Desc throw) o1 ->
      red_expr S C (spec_object_put_5 o1) o ->
      red_expr S0 C (spec_object_put_4 lthis l x v throw (dret S D)) o

  | red_spec_object_put_4_not_accessor_prim : forall S0 S C (wthis:prim) D l x v throw Ad o, (* Step 6, for prim values *)
      (D = full_descriptor_undef) \/ (D = (attributes_data_of Ad)) ->
      red_expr S C (spec_error_or_void throw native_error_type) o ->
      red_expr S0 C (spec_object_put_4 wthis l x v throw (dret S D)) o

  | red_spec_object_put_5_return : forall S0 S C rv, (* Steps 3.c and 7 *)
      red_expr S0 C (spec_object_put_5 (out_ter S rv)) (out_void S)

  (** HasProperty (8.12.6) *)

  | red_spec_object_has_prop_1_default : forall S C l x y1 o, (* Step 1 *)
      red_spec S C (spec_object_get_prop l x) y1 ->
      red_expr S C (spec_object_has_prop_2 y1) o ->
      red_expr S C (spec_object_has_prop_1 builtin_has_prop_default l x) o

  | red_spec_object_has_prop_2 : forall S0 S C D b, (* Steps 2 and 3 *)
      b = (If D = full_descriptor_undef then false else true) ->
      red_expr S0 C (spec_object_has_prop_2 (ret S D)) (out_ter S b)

  (** Delete (8.12.7) *)

  | red_spec_object_delete_1_default : forall S C l x throw o (y:specret full_descriptor), (* Step 1 *)
      red_spec S C (spec_object_get_own_prop l x) y ->
      red_expr S C (spec_object_delete_2 l x throw y) o ->
      red_expr S C (spec_object_delete_1 builtin_delete_default l x throw) o

  | red_spec_object_delete_2_undef : forall S0 S C l x throw, (* Step 2 *)
      red_expr S0 C (spec_object_delete_2 l x throw (ret S full_descriptor_undef)) (out_ter S true)

  (* LATER: tracing events for for-in; see rule below for now.
  | red_spec_object_delete_2_some_configurable : forall S0 S C l x throw A S' o ev, (* Step 3 *)
      attributes_configurable A = true ->
      object_rem_property S l x S' ->
      make_delete_event S' l x ev ->
      red_expr S0 C (spec_object_delete_2 l x throw (ret S (full_descriptor_some A))) (out_ter (state_with_new_event S' ev) true)
  *)

  | red_spec_object_delete_2_some_configurable : forall S0 S C l x throw A S', (* Step 3 *)
      attributes_configurable A = true ->
      object_rem_property S l x S' ->
      red_expr S0 C (spec_object_delete_2 l x throw (ret S (full_descriptor_some A))) (out_ter S' true)

  | red_spec_object_delete_3_some_non_configurable : forall S0 S C l x throw A o, (* Steps 4 and 5 *)
      attributes_configurable A = false ->
      red_expr S C (spec_error_or_cst throw native_error_type false) o ->
      red_expr S0 C (spec_object_delete_2 l x throw (ret S (full_descriptor_some A))) o

  (** DefaultValue (8.12.8)
      Note: rules are better factorized than the specification *)

  | red_spec_object_default_value_1_default : forall S C l prefo pref o,
      pref = unsome_default preftype_number prefo ->
      red_expr S C (spec_object_default_value_2 l pref (other_preftypes pref)) o ->
      red_expr S C (spec_object_default_value_1 builtin_default_value_default l prefo) o

  | red_spec_object_default_value_2 : forall S C l pref1 pref2 o,
      red_expr S C (spec_object_default_value_sub_1 l (method_of_preftype pref1) (spec_object_default_value_3 l pref2)) o ->
      red_expr S C (spec_object_default_value_2 l pref1 pref2) o

  | red_spec_object_default_value_3 : forall S C l pref2 o,
      red_expr S C (spec_object_default_value_sub_1 l (method_of_preftype pref2) spec_object_default_value_4) o ->
      red_expr S C (spec_object_default_value_3 l pref2) o

  | red_spec_object_default_value_4 : forall S C o,
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C spec_object_default_value_4 o

  (** Auxiliary reduction rules for DefaultValue (in continuation-passing-style) *)

  | red_spec_object_default_value_sub_1 : forall o1 S C l x K o,
      red_expr S C (spec_object_get l x) o1 ->
      red_expr S C (spec_object_default_value_sub_2 l o1 K) o ->
      red_expr S C (spec_object_default_value_sub_1 l x K) o

  | red_spec_object_default_value_sub_2_not_callable : forall S0 S C l v K o,
      callable S v None ->
      red_expr S C K o ->
      red_expr S0 C (spec_object_default_value_sub_2 l (out_ter S v) K) o

  | red_spec_object_default_value_sub_2_callable : forall S0 S C lfunc l v K o B o1,
      callable S v (Some B) ->
      v = value_object lfunc ->
      red_expr S C (spec_call lfunc l nil) o1 ->
      red_expr S C (spec_object_default_value_sub_3 o1 K) o ->
      red_expr S0 C (spec_object_default_value_sub_2 l (out_ter S v) K) o
      (* Note: the spec does not mention a call [getValue] on the result of the [[call]] *)

  | red_spec_object_default_value_sub_3_prim : forall S0 S C K w,
      red_expr S0 C (spec_object_default_value_sub_3 (out_ter S w) K) (out_ter S w)

  | red_spec_object_default_value_sub_3_object : forall S0 S C l K o,
      red_expr S C K o ->
      red_expr S0 C (spec_object_default_value_sub_3 (out_ter S (value_object l)) K) o

  (** DefineOwnProperty (8.12.9) *)

  | red_spec_object_define_own_prop_1_default : forall S C l x Desc throw o (y:specret full_descriptor), (* Step 1 *)
      red_spec S C (spec_object_get_own_prop l x) y ->
      red_expr S C (spec_object_define_own_prop_2 l x Desc throw y) o ->
      red_expr S C (spec_object_define_own_prop_1 builtin_define_own_prop_default l x Desc throw) o

  | red_spec_object_define_own_prop_2 : forall S0 S C l x Desc throw An bext o, (* Step 2 *)
      object_extensible S l bext ->
      red_expr S C (spec_object_define_own_prop_3 l x Desc throw An bext) o ->
      red_expr S0 C (spec_object_define_own_prop_2 l x Desc throw (ret S An)) o
      (* LATER: This [An] is a [full_descriptor]:  why not calling it [D]? -- Martin *)

  | red_spec_object_define_own_prop_3_undef_false : forall S C l x Desc throw o, (* Step 3 *)
      red_expr S C (spec_object_define_own_prop_reject throw) o ->
      red_expr S C (spec_object_define_own_prop_3 l x Desc throw full_descriptor_undef false) o

  | red_spec_object_define_own_prop_3_undef_true : forall S C l x Desc throw A S', (* Step 4 *)
      A = (If (descriptor_is_generic Desc \/ descriptor_is_data Desc)
            then attributes_data_of_descriptor Desc
            else attributes_accessor_of_descriptor Desc) ->
      object_set_property S l x A S' ->
      red_expr S C (spec_object_define_own_prop_3 l x Desc throw full_descriptor_undef true) (out_ter S' true)

  | red_spec_object_define_own_prop_3_includes : forall S C l x A Desc throw bext, (* Step 6 (subsumes 5) *)
      descriptor_contains A Desc ->
      red_expr S C (spec_object_define_own_prop_3 l x Desc throw (full_descriptor_some A) bext) (out_ter S true)

  | red_spec_object_define_own_prop_3_not_include : forall S C l x A Desc throw o bext, (* Steps 6 else branch *)
      ~ descriptor_contains A Desc ->
      red_expr S C (spec_object_define_own_prop_4 l x A Desc throw) o ->
      red_expr S C (spec_object_define_own_prop_3 l x Desc throw (full_descriptor_some A) bext) o

  | red_spec_object_define_own_prop_4_reject : forall S C l x A Desc throw o, (* Step 7 *)
      attributes_change_enumerable_on_non_configurable A Desc ->
      red_expr S C (spec_object_define_own_prop_reject throw) o ->
      red_expr S C (spec_object_define_own_prop_4 l x A Desc throw) o

  | red_spec_object_define_own_prop_4_not_reject : forall S C l x A Desc throw o, (* Step 7 else branch *)
      ~ attributes_change_enumerable_on_non_configurable A Desc ->
      red_expr S C (spec_object_define_own_prop_5 l x A Desc throw) o ->
      red_expr S C (spec_object_define_own_prop_4 l x A Desc throw) o

  | red_spec_object_define_own_prop_5_generic : forall S C l x A Desc throw o, (* Step 8 *)
      descriptor_is_generic Desc ->
      red_expr S C (spec_object_define_own_prop_write l x A Desc throw) o ->
      red_expr S C (spec_object_define_own_prop_5 l x A Desc throw) o

  | red_spec_object_define_own_prop_5_a : forall S C l x A Desc throw o, (* Step 9 *)
      (attributes_is_data A) <> (descriptor_is_data Desc) ->
      red_expr S C (spec_object_define_own_prop_6a l x A Desc throw) o ->
      red_expr S C (spec_object_define_own_prop_5 l x A Desc throw) o

  | red_spec_object_define_own_prop_6a_reject : forall S C l x A Desc throw o, (* Step 9a *)
      attributes_configurable A = false ->
      red_expr S C (spec_object_define_own_prop_reject throw) o ->
      red_expr S C (spec_object_define_own_prop_6a l x A Desc throw) o

  | red_spec_object_define_own_prop_6a_accept : forall S S' C l x A A' Desc throw o, (* Steps 9b and 9c *)
      attributes_configurable A = true ->
      A' = match A with
           | attributes_data_of Ad => attributes_accessor_of_attributes_data Ad
           | attributes_accessor_of Aa => attributes_data_of_attributes_accessor Aa
           end ->
      object_set_property S l x A' S' ->
      red_expr S' C (spec_object_define_own_prop_write l x A' Desc throw) o ->
      red_expr S C (spec_object_define_own_prop_6a l x A Desc throw) o

  | red_spec_object_define_own_prop_5_b : forall S C l x Ad Desc throw o, (* Step 10 *)
      descriptor_is_data Desc ->
      red_expr S C (spec_object_define_own_prop_6b l x Ad Desc throw) o ->
      red_expr S C (spec_object_define_own_prop_5 l x (attributes_data_of Ad) Desc throw) o

  | red_spec_object_define_own_prop_6b_false_reject : forall S C l x Ad Desc throw o, (* Step 10a *)
      attributes_change_data_on_non_configurable Ad Desc ->
      red_expr S C (spec_object_define_own_prop_reject throw) o ->
      red_expr S C (spec_object_define_own_prop_6b l x Ad Desc throw) o

  | red_spec_object_define_own_prop_6b_false_accept : forall S C l x Ad Desc throw o, (* Step 10a else branch *)
      ~ (attributes_change_data_on_non_configurable Ad Desc) ->
      red_expr S C (spec_object_define_own_prop_write l x Ad Desc throw) o ->
      red_expr S C (spec_object_define_own_prop_6b l x Ad Desc throw) o

  | red_spec_object_define_own_prop_5_c : forall S C l x Aa Desc throw o, (* Step 11 *)
      descriptor_is_accessor Desc ->
      red_expr S C (spec_object_define_own_prop_6c l x Aa Desc throw) o ->
      red_expr S C (spec_object_define_own_prop_5 l x (attributes_accessor_of Aa) Desc throw) o

  | red_spec_object_define_own_prop_6c_1 : forall S C l x Aa Desc throw o, (* Step 11a *)
      attributes_change_accessor_on_non_configurable Aa Desc ->
      red_expr S C (spec_object_define_own_prop_reject throw) o ->
      red_expr S C (spec_object_define_own_prop_6c l x Aa Desc throw) o

   | red_spec_object_define_own_prop_6c_2 : forall S C l x Aa Desc throw o, (* Step 11a else branch *)
      ~ attributes_change_accessor_on_non_configurable Aa Desc ->
      red_expr S C (spec_object_define_own_prop_write l x Aa Desc throw) o ->
      red_expr S C (spec_object_define_own_prop_6c l x Aa Desc throw) o

  | red_spec_object_define_own_prop_write : forall S S' C l x A Desc throw A',
      A' = attributes_update A Desc ->
      object_set_property S l x A' S' ->
      red_expr S C (spec_object_define_own_prop_write l x A Desc throw) (out_ter S' true)

  | red_spec_object_define_own_prop_reject : forall S C throw o,
      red_expr S C (spec_error_or_cst throw native_error_type false) o ->
      red_expr S C (spec_object_define_own_prop_reject throw) o


  (*------------------------------------------------------------*)
  (** ** Operations on references (8.7) *)

    (** Get value on a reference (returns value) (8.7.1) --- MOVED *)

  (** Special Get method for primitive values (returns value)  (8.7.1)
      Note: implemented with the same rules as [spec_object_get] *)

  | red_spec_prim_value_get : forall S C v x o1 o,
      red_expr S C (spec_to_object v) o1 ->
      red_expr S C (spec_prim_value_get_1 v x o1) o ->
      red_expr S C (spec_prim_value_get v x) o

  | red_spec_prim_value_get_1 : forall S0 S C v x l o,
      red_expr S C (spec_object_get_1 builtin_get_default v l x) o ->
      red_expr S0 C (spec_prim_value_get_1 v x (out_ter S l)) o

  (** Put value on a reference (returns void) (8.7.2) *)

  | red_spec_ref_put_value_value : forall S C v vnew o, (* Step 1 *)
      red_expr S C (spec_error native_error_ref) o ->
      red_expr S C (spec_put_value v vnew) o

  | red_spec_ref_put_value_ref_a_1 : forall S C r vnew o, (* Steps 2 and 3a *)
      ref_is_unresolvable r ->
      ref_strict r = true ->
      red_expr S C (spec_error native_error_ref) o ->
      red_expr S C (spec_put_value r vnew) o

  | red_spec_ref_put_value_ref_a_2 : forall o S C r vnew, (* Steps 2 and 3b *)
      ref_is_unresolvable r ->
      ref_strict r = false ->
      red_expr S C (spec_object_put prealloc_global (ref_name r) vnew throw_false) o ->
      red_expr S C (spec_put_value r vnew) o

  | red_spec_ref_put_value_ref_b_has_primitive_base : forall v S C r vnew o, (* Step 4 *)
      ref_is_property r ->
      ref_base r = ref_base_type_value v ->
      ref_has_primitive_base r ->
      red_expr S C (spec_prim_value_put v (ref_name r) vnew (ref_strict r)) o ->
      red_expr S C (spec_put_value (resvalue_ref r) vnew) o

  | red_spec_ref_put_value_ref_b_has_not_primitive_base : forall l S C r vnew o, (* Step 4 *)
      ref_is_property r ->
      ref_base r = ref_base_type_value l ->
      ~ ref_has_primitive_base r ->
      red_expr S C (spec_object_put l (ref_name r) vnew (ref_strict r)) o ->
      red_expr S C (spec_put_value (resvalue_ref r) vnew) o

  | red_spec_ref_put_value_ref_c : forall L S C r vnew o, (* Step 5 *)
      ref_base r = ref_base_type_env_loc L ->
      red_expr S C (spec_env_record_set_mutable_binding L (ref_name r) vnew (ref_strict r)) o ->
      red_expr S C (spec_put_value (resvalue_ref r) vnew) o

  (** Special "Put" method for primitive values (returns value)  (8.7.2)
      Note: implemented with the same rules as [spec_object_put]*)

  | red_spec_prim_value_put : forall S C v x v1 throw o1 o,
      red_expr S C (spec_to_object v) o1 ->
      red_expr S C (spec_prim_value_put_1 v x v1 throw o1) o ->
      red_expr S C (spec_prim_value_put v x v1 throw) o

  | red_spec_prim_value_put_1 : forall S0 S C v x v1 throw l o,
      red_expr S C (spec_object_put_1 builtin_put_default v l x v1 throw) o ->
      red_expr S0 C (spec_prim_value_put_1 v x v1 throw (out_ter S l)) o



  (*------------------------------------------------------------*)
  (** ** Operations on environment records (10.2) *)

  (** Has binding (returns bool) (10.2.1.1.1, 10.2.1.2.1) *)

  | red_spec_env_record_has_binding : forall S C L x o E,
      env_record_binds S L E ->
      red_expr S C (spec_env_record_has_binding_1 L x E) o ->
      red_expr S C (spec_env_record_has_binding L x) o

  | red_spec_env_record_has_binding_1_decl : forall S C L x Ed b,
      b = (If decl_env_record_indom Ed x then true else false) ->
      red_expr S C (spec_env_record_has_binding_1 L x (env_record_decl Ed)) (out_ter S b)

  | red_spec_env_record_has_binding_1_object : forall S C L x l pt o,
      red_expr S C (spec_object_has_prop l x) o ->
      red_expr S C (spec_env_record_has_binding_1 L x (env_record_object l pt)) o

  (** Create mutable binding (returns void) (10.2.1.1.2, 10.2.1.2.2) *)

  | red_spec_env_record_create_mutable_binding : forall S C L x deletable_opt deletable o E,
      deletable = unsome_default false deletable_opt ->
      env_record_binds S L E ->
      red_expr S C (spec_env_record_create_mutable_binding_1 L x deletable E) o ->
      red_expr S C (spec_env_record_create_mutable_binding L x deletable_opt) o

  | red_spec_env_record_create_mutable_binding_1_decl_indom : forall S C L x deletable Ed S',
      ~ decl_env_record_indom Ed x ->
      S' = env_record_write_decl_env S L Ed x (mutability_of_bool deletable) undef ->
      red_expr S C (spec_env_record_create_mutable_binding_1 L x deletable (env_record_decl Ed)) (out_void S')

  | red_spec_env_record_create_mutable_binding_1_object : forall o1 S C L x deletable l pt o,
      red_expr S C (spec_object_has_prop l x) o1 ->
      red_expr S C (spec_env_record_create_mutable_binding_2 L x deletable l o1) o ->
      red_expr S C (spec_env_record_create_mutable_binding_1 L x deletable (env_record_object l pt)) o

  | red_spec_env_record_create_mutable_binding_obj_2 : forall A S0 C L x deletable l S o1 o,
      A = attributes_data_intro undef true true deletable ->
      red_expr S C (spec_object_define_own_prop l x A throw_true) o1 ->
      red_expr S C (spec_env_record_create_mutable_binding_3 o1) o ->
      red_expr S0 C (spec_env_record_create_mutable_binding_2 L x deletable l (out_ter S false)) o

  | red_spec_env_record_create_mutable_binding_obj_3 : forall S0 S C rv,
      red_expr S0 C (spec_env_record_create_mutable_binding_3 (out_ter S rv)) (out_void S)

  (** Set mutable binding (returns void) (10.2.1.1.3, 10.2.1.2.3) *)

  | red_spec_env_record_set_mutable_binding : forall S C L x v str o E,
      env_record_binds S L E ->
      red_expr S C (spec_env_record_set_mutable_binding_1 L x v str E) o ->
      red_expr S C (spec_env_record_set_mutable_binding L x v str) o

  | red_spec_env_record_set_mutable_binding_1_decl : forall v_old mu S C L x v str Ed K o,
      decl_env_record_binds Ed x mu v_old ->
      K = (If mutability_is_mutable mu
            then (let S' := env_record_write_decl_env S L Ed x mu v in
                  spec_returns (out_void S'))
            else (spec_error_or_void str native_error_type)) ->
      red_expr S C K o ->
      red_expr S C (spec_env_record_set_mutable_binding_1 L x v str (env_record_decl Ed)) o

  | red_spec_env_record_set_mutable_binding_1_object : forall S C L x v str l pt o,
      red_expr S C (spec_object_put l x v str) o ->
      red_expr S C (spec_env_record_set_mutable_binding_1 L x v str (env_record_object l pt)) o

  (** Get binding value (returns value) (10.2.1.1.4, 10.2.1.2.4) *)

  | red_spec_env_record_get_binding_value : forall E S C L x str o,
      env_record_binds S L E ->
      red_expr S C (spec_env_record_get_binding_value_1 L x str E) o ->
      red_expr S C (spec_env_record_get_binding_value L x str) o

  | red_spec_env_record_get_binding_value_1_decl : forall mu v S C L x str Ed K o,
      decl_env_record_binds Ed x mu v ->
      K = (If mu = mutability_uninitialized_immutable
              then (spec_error_or_cst str native_error_ref undef)
              else spec_returns (out_ter S v)) ->
      red_expr S C K o ->
      red_expr S C (spec_env_record_get_binding_value_1 L x str (env_record_decl Ed)) o

  | red_spec_env_record_get_binding_value_1_object : forall o1 S C L x str l pt o,
      red_expr S C (spec_object_has_prop l x) o1 ->
      red_expr S C (spec_env_record_get_binding_value_2 x str l o1) o ->
      red_expr S C (spec_env_record_get_binding_value_1 L x str (env_record_object l pt)) o

  | red_spec_env_record_get_binding_value_obj_2_false : forall S0 C x str l S o,
      red_expr S C (spec_error_or_cst str native_error_ref undef) o ->
      red_expr S0 C (spec_env_record_get_binding_value_2 x str l (out_ter S false)) o

  | red_spec_env_record_get_binding_value_obj_2_true : forall S0 C x str l S o,
      red_expr S C (spec_object_get l x) o ->
      red_expr S0 C (spec_env_record_get_binding_value_2 x str l (out_ter S true)) o

  (** Delete binding (returns bool) (10.2.1.1.5, 10.2.1.2.5) *)

  | red_spec_env_record_delete_binding : forall S C L x o E,
      env_record_binds S L E ->
      red_expr S C (spec_env_record_delete_binding_1 L x E) o ->
      red_expr S C (spec_env_record_delete_binding L x) o

  | red_spec_env_record_delete_binding_1_decl_indom : forall mu v S C L x Ed S' b,
      decl_env_record_binds Ed x mu v ->
      (If mu = mutability_deletable
          then (S' = env_record_write S L (decl_env_record_rem Ed x) /\ b = true)
          else (S' = S /\ b = false)) ->
      red_expr S C (spec_env_record_delete_binding_1 L x (env_record_decl Ed)) (out_ter S' b)

  | red_spec_env_record_delete_binding_1_decl_not_indom : forall S C L x Ed,
      ~ decl_env_record_indom Ed x ->
      red_expr S C (spec_env_record_delete_binding_1 L x (env_record_decl Ed)) (out_ter S true)

  | red_spec_env_record_delete_binding_1_object : forall S C L x l pt o,
      red_expr S C (spec_object_delete l x throw_false) o ->
      red_expr S C (spec_env_record_delete_binding_1 L x (env_record_object l pt)) o

  (** Implicit this value (returns value) (10.2.1.1.6, 10.2.1.2.6) *)

  | red_spec_env_record_implicit_this_value : forall S C L o E,
      env_record_binds S L E ->
      red_expr S C (spec_env_record_implicit_this_value_1 L E) o ->
      red_expr S C (spec_env_record_implicit_this_value L) o

  | red_spec_env_record_implicit_this_value_1_decl : forall S C L Ed,
      red_expr S C (spec_env_record_implicit_this_value_1 L (env_record_decl Ed)) (out_ter S undef)

  | red_spec_env_record_implicit_this_value_1_object : forall S C L l (pt : bool) v,
      v = (if pt then l else undef) ->
      red_expr S C (spec_env_record_implicit_this_value_1 L (env_record_object l pt)) (out_ter S v)

  (** Create immutable binding (returns void) (10.2.1.1.7) *)

  | red_spec_env_record_create_immutable_binding : forall Ed S C L x S',
      env_record_binds S L (env_record_decl Ed) ->
      ~ decl_env_record_indom Ed x ->
      S' = env_record_write_decl_env S L Ed x mutability_uninitialized_immutable undef ->
      red_expr S C (spec_env_record_create_immutable_binding L x) (out_void S')

  (** Initialize immutable binding (returns void) (10.2.1.1.8) *)

  | red_spec_env_record_initialize_immutable_binding : forall Ed v_old S C L x v S',
      env_record_binds S L (env_record_decl Ed) ->
      decl_env_record_binds Ed x mutability_uninitialized_immutable v_old -> (* Note: v_old is always undef here *)
      S' = env_record_write_decl_env S L Ed x mutability_immutable v ->
      red_expr S C (spec_env_record_initialize_immutable_binding L x v) (out_void S')

  (** Auxiliary: combination of create mutable binding and set mutable binding (returns void) *)

  | red_spec_env_record_create_set_mutable_binding : forall S C L x deletable_opt v str o o1,
      red_expr S C (spec_env_record_create_mutable_binding L x deletable_opt) o1 ->
      red_expr S C (spec_env_record_create_set_mutable_binding_1 o1 L x v str) o ->
      red_expr S C (spec_env_record_create_set_mutable_binding L x deletable_opt v str) o

  | red_spec_env_record_create_set_mutable_binding_1 : forall S S0 C L x v str o,
      red_expr S C (spec_env_record_set_mutable_binding L x v str) o ->
      red_expr S0 C (spec_env_record_create_set_mutable_binding_1 (out_void S) L x v str) o

  (*------------------------------------------------------------*)
  (** ** Operations on execution contexts and entering of function code (10.4) *)

  (** Entering eval code  (10.4.2) *)

  | red_spec_entering_eval_code : forall (str:bool) C' S C (bdirect:bool) bd K o, (* Steps 1 - 2 *)
      str = funcbody_is_strict bd || (bdirect && execution_ctx_strict C)->
      C' = (If bdirect then C else execution_ctx_initial str) ->
      red_expr S C' (spec_entering_eval_code_1 bd K str) o ->
      red_expr S C (spec_entering_eval_code bdirect bd K) o

  | red_spec_entering_eval_code_1 : forall (str:bool) lex S' C' o1 S C bd K o, (* Steps 3 - 4 *)
      (lex, S') = (If str then lexical_env_alloc_decl S (execution_ctx_lexical_env C)
                          else (execution_ctx_lexical_env C, S)) ->
      C' = (If str then (execution_ctx_with_lex_same C lex) else C) ->
      red_expr S' C' (spec_binding_inst codetype_eval None (funcbody_prog bd) nil) o1 ->
      red_expr S' C' (spec_entering_eval_code_2 o1 K) o ->
      red_expr S C (spec_entering_eval_code_1 bd K str) o

  | red_spec_entering_eval_code_2 : forall S0 C S K o, (* Call continuation *)
      red_expr S C K o ->
      red_expr S0 C (spec_entering_eval_code_2 (out_void S) K) o

  (** Entering function code  (10.4.3) *)

  | red_spec_entering_func_code : forall S C lf vthis args bd str K o,
      object_method object_code_ S lf (Some bd) ->
      str = funcbody_is_strict bd ->
      red_expr S C (spec_entering_func_code_1 lf args bd vthis str K) o ->
      red_expr S C (spec_entering_func_code lf vthis args K) o

  | red_spec_entering_func_code_1_strict : forall S C lf args bd vthis K o, (* Step 1 *)
      red_expr S C (spec_entering_func_code_3 lf args true bd vthis K) o ->
      red_expr S C (spec_entering_func_code_1 lf args bd vthis strictness_true K) o

  | red_spec_entering_func_code_1_null_or_undef : forall S C lf args bd vthis K o, (* Step 2 *)
      (vthis = null \/ vthis = undef) ->
      red_expr S C (spec_entering_func_code_3 lf args false bd prealloc_global K) o ->
      red_expr S C (spec_entering_func_code_1 lf args bd vthis strictness_false K) o

  | red_spec_entering_func_code_1_not_object : forall S C lf args bd vthis o1 K o, (* Step 3 *)
      (vthis <> null /\ vthis <> undef /\ type_of vthis <> type_object) ->
      red_expr S C (spec_to_object vthis) o1 ->
      red_expr S C (spec_entering_func_code_2 lf args bd o1 K) o ->
      red_expr S C (spec_entering_func_code_1 lf args bd vthis strictness_false K) o

  | red_spec_entering_func_code_2 : forall S S0 C lf args bd vthis K o, (* Step 3, continued *)
      red_expr S C (spec_entering_func_code_3 lf args strictness_false bd vthis K) o ->
      red_expr S0 C (spec_entering_func_code_2 lf args bd (out_ter S vthis) K) o

  | red_spec_entering_func_code_1_object : forall S C lf args bd (lthis:object_loc) K o, (* Step 4 *)
      red_expr S C (spec_entering_func_code_3 lf args strictness_false bd lthis K) o ->
      red_expr S C (spec_entering_func_code_1 lf args bd lthis strictness_false K) o

  | red_spec_entering_func_code_3 : forall lex' S' C' o1 S C lf args str bd vthis lex  K o, (* Steps 5 through 9 *)
      object_method object_scope_ S lf (Some lex) ->
      (lex', S') = lexical_env_alloc_decl S lex ->
      C' = execution_ctx_intro_same lex' vthis str ->
      red_expr S' C' (spec_binding_inst codetype_func (Some lf) (funcbody_prog bd) args) o1 ->
      red_expr S' C' (spec_entering_func_code_4 o1 K) o ->
      red_expr S C (spec_entering_func_code_3 lf args str bd vthis K) o

  | red_spec_entering_func_code_4 : forall S0 S C K o, (* Call continuation *)
      red_expr S C K o ->
      red_expr S0 C (spec_entering_func_code_4 (out_void S) K) o


  (*------------------------------------------------------------*)
  (** Binding instantiation (10.5) *)

  (* Auxiliary reductions for binding instantiation:
     bindings for parameters (Step 4d). *)

  | red_spec_binding_inst_formal_params_empty : forall S C args L str,  (* Loop ends in Step 4d *)
      red_expr S C (spec_binding_inst_formal_params args L nil str) (out_void S)

  | red_spec_binding_inst_formal_params_non_empty : forall v args' S C args L x xs str o1 o, (* Steps 4d i - iii *)
      (v,args') = (match args with nil => (undef,nil) | v::args' => (v,args') end) ->
      red_expr S C (spec_env_record_has_binding L x) o1 ->
      red_expr S C (spec_binding_inst_formal_params_1 args' L x xs str v o1) o ->
      red_expr S C (spec_binding_inst_formal_params args L (x::xs) str) o

  | red_spec_binding_inst_formal_params_1_not_declared : forall S0 S C args L x xs str v o o1, (* Step 4d iv *)
      red_expr S C (spec_env_record_create_mutable_binding L x None) o1 ->
      (* LATER(Daiva): are we sure that deletable_opt above is None, meaning that the item
         will not be deletable? it's worth testing in an implementation if you can delete an arg binding.
         gds: I believe this is correct. I'm leaving the comment in, but changing to LATER because it's an interesting area to test later. *)
      red_expr S C (spec_binding_inst_formal_params_2 args L x xs str v o1) o ->
      red_expr S0 C (spec_binding_inst_formal_params_1 args L x xs str v (out_ter S false)) o

  | red_spec_binding_inst_formal_params_2 : forall S0 S C args L x xs str v o, (* Step 4d iv join *)
      red_expr S C (spec_binding_inst_formal_params_3 args L x xs str v) o ->
      red_expr S0 C (spec_binding_inst_formal_params_2 args L x xs str v (out_void S)) o

  | red_spec_binding_inst_formal_params_1_declared : forall S0 S C args L x xs str v o, (* Step 4d iv else *)
      red_expr S C (spec_binding_inst_formal_params_3 args L x xs str v) o ->
      red_expr S0 C (spec_binding_inst_formal_params_1 args L x xs str v (out_ter S true)) o

  | red_spec_binding_inst_formal_params_3 : forall o1 S C args L x xs str v o, (* Step 4d v *)
      red_expr S C (spec_env_record_set_mutable_binding L x v str) o1 ->
      red_expr S C (spec_binding_inst_formal_params_4 args L xs str o1) o ->
      red_expr S C (spec_binding_inst_formal_params_3 args L x xs str v) o

  | red_spec_binding_inst_formal_params_4 : forall S0 S C args L xs str o, (* Step 4d loop *)
      red_expr S C (spec_binding_inst_formal_params args L xs str) o ->
      red_expr S0 C (spec_binding_inst_formal_params_4 args L xs str (out_void S)) o

  (* Auxiliary reductions for binding instantiation:
     bindings for function declarations (Step 5). *)
  (* LATER: remove "args" as it's not used at all in this subroutine *)

  | red_spec_binding_inst_function_decls_nil : forall L S C str bconfig, (* Step 5b *)
      red_expr S C (spec_binding_inst_function_decls L nil str bconfig) (out_void S)

  | red_spec_binding_inst_function_decls_cons : forall str_fd S C L fd fds str bconfig o1 o, (* Step 5b *)
      str_fd = funcbody_is_strict (funcdecl_body fd) ->
      red_expr S C (spec_creating_function_object (funcdecl_parameters fd) (funcdecl_body fd) (execution_ctx_variable_env C) str_fd) o1 ->
      red_expr S C (spec_binding_inst_function_decls_1 L fd fds str bconfig o1) o ->
      red_expr S C (spec_binding_inst_function_decls L (fd::fds) str bconfig) o

  | red_spec_binding_inst_function_decls_1 : forall o1 L S0 S C fd fds str fo bconfig o, (* Step 5c *)
      red_expr S C (spec_env_record_has_binding L (funcdecl_name fd)) o1 ->
      red_expr S C (spec_binding_inst_function_decls_2 L fd fds str fo bconfig o1) o ->
      red_expr S0 C (spec_binding_inst_function_decls_1 L fd fds str bconfig (out_ter S fo)) o

  | red_spec_binding_inst_function_decls_2_false : forall o1 L S0 S C fd fds str fo bconfig o, (* Step 5d *)
      red_expr S C (spec_env_record_create_mutable_binding L (funcdecl_name fd) (Some bconfig)) o1 ->
      red_expr S C (spec_binding_inst_function_decls_4 L fd fds str fo bconfig o1) o ->
      red_expr S0 C (spec_binding_inst_function_decls_2 L fd fds str fo bconfig (out_ter S false)) o

  | red_spec_binding_inst_function_decls_2_true_global : forall S0 S C fd fds str fo bconfig y1 o, (* Step 5e ii *)
      red_spec S C (spec_object_get_prop prealloc_global (funcdecl_name fd)) y1 ->
      red_expr S C (spec_binding_inst_function_decls_3 fd fds str fo bconfig y1) o ->
      red_expr S0 C (spec_binding_inst_function_decls_2 env_loc_global_env_record fd fds str fo bconfig (out_ter S true)) o

  | red_spec_binding_inst_function_decls_3_true : forall S0 S C fd fds str fo bconfig A Anew o1 o, (* Step 5e iii *)
      attributes_configurable A = true ->
      Anew = attributes_data_intro undef true true bconfig ->
      red_expr S C (spec_object_define_own_prop prealloc_global (funcdecl_name fd) Anew true) o1 ->
      red_expr S C (spec_binding_inst_function_decls_4 env_loc_global_env_record fd fds str fo bconfig o1) o ->
      red_expr S0 C (spec_binding_inst_function_decls_3 fd fds str fo bconfig (ret S (full_descriptor_some A))) o

  | red_spec_binding_inst_function_decls_4 : forall S0 S C L fd fds str fo bconfig rv o, (* Step 5e iii *)
      red_expr S C (spec_binding_inst_function_decls_5 L fd fds str fo bconfig) o ->
      red_expr S0 C (spec_binding_inst_function_decls_4 L fd fds str fo bconfig (out_ter S rv)) o

  | red_spec_binding_inst_function_decls_3_false : forall S0 S C fd fds str fo A bconfig o, (* Step 5e iii, else *)
      attributes_configurable A = false ->
      red_expr S C (spec_binding_inst_function_decls_3a fd fds str fo bconfig A) o ->
      red_expr S0 C (spec_binding_inst_function_decls_3 fd fds str fo bconfig (ret S (full_descriptor_some A))) o

  | red_spec_binding_inst_function_decls_3a_type_error : forall S C fd fds str fo A bconfig o, (* Step 5e iv *)
      (* LATER: descriptor_is_accessor A \/ ~ (attributes_writable A = true /\ attributes_enumerable A = true) ->  *)
      descriptor_is_accessor A \/ attributes_writable A = false \/ attributes_enumerable A = false ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (spec_binding_inst_function_decls_3a fd fds str fo bconfig A) o

  | red_spec_binding_inst_function_decls_3a_no_error : forall S C fd fds str fo A bconfig o1 o, (* Step 5e iv else *)
      ~ (descriptor_is_accessor A \/ attributes_writable A = false \/ attributes_enumerable A = false) ->
      red_expr S C (spec_binding_inst_function_decls_5 env_loc_global_env_record fd fds str fo bconfig) o ->
      red_expr S C (spec_binding_inst_function_decls_3a fd fds str fo bconfig A) o

  | red_spec_binding_inst_function_decls_2_true : forall L S0 S C fd fds str fo bconfig o, (* Step 5e *)
      L <> env_loc_global_env_record ->
      red_expr S C (spec_binding_inst_function_decls_5 L fd fds str fo bconfig) o ->
      red_expr S0 C (spec_binding_inst_function_decls_2 L fd fds str fo bconfig (out_ter S true)) o

  | red_spec_binding_inst_function_decls_5 : forall o1 L S C fd fds str fo bconfig o, (* Step 5f *)
      red_expr S C (spec_env_record_set_mutable_binding L (funcdecl_name fd) (value_object fo) str) o1 ->
      red_expr S C (spec_binding_inst_function_decls_6 L fds str bconfig o1) o ->
      red_expr S C (spec_binding_inst_function_decls_5 L fd fds str fo bconfig) o

  | red_spec_binding_inst_function_decls_6 : forall L S0 S C fds str bconfig o, (* Step 5 loop *)
      red_expr S C (spec_binding_inst_function_decls L fds str bconfig) o ->
      red_expr S0 C (spec_binding_inst_function_decls_6 L fds str bconfig (out_void S)) o

  (* Auxiliary reductions for binding instantiation:
     Declaring Arguments Object (Step 7) *)

  | red_spec_binding_inst_arg_obj : forall str o1 L S C lf xs args o, (* Step 7a *)
      (* We actually need the variable environment with its pointer to parent variable environment for arguments object since it creates function objects.
         But we forget the parents at the very first step of Declaration Binding Instantiation. We do not change execution context in Declaration Binding
         Instaniation. So it is save to take the variable environment from execution context here. For the right way to do, should it be saved at the first
         step and then propagated until this point? *)
      red_expr S C (spec_create_arguments_object lf xs args (execution_ctx_variable_env C) str) o1 ->
      red_expr S C (spec_binding_inst_arg_obj_1 L str o1) o ->
      red_expr S C (spec_binding_inst_arg_obj lf xs args L str) o

  | red_spec_binding_inst_arg_obj_1_strict : forall o1 L S0 S C largs o, (* Step 7b i *)
      red_expr S C (spec_env_record_create_immutable_binding L "arguments") o1 ->
      red_expr S C (spec_binding_inst_arg_obj_2 L largs o1) o ->
      red_expr S0 C (spec_binding_inst_arg_obj_1 L true (out_ter S largs)) o

  | red_spec_binding_inst_arg_obj_2 : forall L S0 S C largs o, (* Step 7b ii *)
      red_expr S C (spec_env_record_initialize_immutable_binding L "arguments" (value_object largs)) o ->
      red_expr S0 C (spec_binding_inst_arg_obj_2 L largs (out_void S)) o

  | red_spec_binding_inst_arg_obj_1_not_strict : forall L S0 S C largs o, (* Step 7c *)
      red_expr S C (spec_env_record_create_set_mutable_binding L "arguments" None largs false) o ->
      red_expr S0 C (spec_binding_inst_arg_obj_1 L false (out_ter S largs)) o

  (* Auxiliary reductions for binding instantiation:
     bindings for variable declarations (Step 8) *)

  | red_spec_binding_inst_var_decls_nil : forall L S C bconfig str, (* Step 8 *)
      red_expr S C (spec_binding_inst_var_decls L nil bconfig str) (out_void S)

  | red_spec_binding_inst_var_decls_cons : forall o1 L S C vd vds bconfig str o, (* Step 8b *)
      red_expr S C (spec_env_record_has_binding L vd) o1 ->
      red_expr S C (spec_binding_inst_var_decls_1 L vd vds bconfig str o1) o ->
      red_expr S C (spec_binding_inst_var_decls L (vd::vds) bconfig str) o

  | red_spec_binding_inst_var_decls_1_true : forall L S0 S C vd vds bconfig str o, (* Step 8c *)
      red_expr S C (spec_binding_inst_var_decls L vds bconfig str) o ->
      red_expr S0 C (spec_binding_inst_var_decls_1 L vd vds bconfig str (out_ter S true)) o

  | red_spec_binding_inst_var_decls_1_false : forall o1 L S0 S C vd vds bconfig str o, (* Step 8c *)
      red_expr S C (spec_env_record_create_set_mutable_binding L vd (Some bconfig) undef str) o1 ->
      red_expr S C (spec_binding_inst_var_decls_2 L vds bconfig str o1) o ->
      red_expr S0 C (spec_binding_inst_var_decls_1 L vd vds bconfig str (out_ter S false)) o

  | red_spec_binding_inst_var_decls_2 : forall L S0 S C vds bconfig str o, (* Step 8c *)
      red_expr S C (spec_binding_inst_var_decls L vds bconfig str) o ->
      red_expr S0 C (spec_binding_inst_var_decls_2 L vds bconfig str (out_void S)) o

  (* Declaration Binding Instantiation: main reduction rules (10.5) *)

  | red_spec_binding_inst : forall L Ls S C ct olf code args o, (* Step 1 *)
      execution_ctx_variable_env C = L::Ls ->
      red_expr S C (spec_binding_inst_1 ct olf code args L) o ->
      red_expr S C (spec_binding_inst ct olf code args) o

  | red_spec_binding_inst_1_function : forall o1 xs S C lf code args L o, (* Step 4a *)
      object_method object_formal_parameters_ S lf (Some xs) ->
      red_expr S C (spec_binding_inst_formal_params args L xs (prog_intro_strictness code)) o1 ->
      red_expr S C (spec_binding_inst_2 codetype_func lf code xs args L o1) o ->
      red_expr S C (spec_binding_inst_1 codetype_func (Some lf) code args L) o

  | red_spec_binding_inst_2 : forall S0 xs S C lf code args L o, (* Step 4a *)
      red_expr S C (spec_binding_inst_3 codetype_func (Some lf) code xs args L) o ->
      red_expr S0 C (spec_binding_inst_2 codetype_func lf code xs args L (out_void S)) o

  | red_spec_binding_inst_1_not_function : forall L S C ct code args o, (* Step 4a not needed *)
      ct <> codetype_func ->
      red_expr S C (spec_binding_inst_3 ct None code nil args L) o ->
      red_expr S C (spec_binding_inst_1 ct None code args L) o

  | red_spec_binding_inst_3 : forall bconfig L S C ct olf code fds xs args o1 o, (* Step 5 *)
      bconfig = (If ct = codetype_eval then true else false) -> (* Step 2 *)
      fds = prog_funcdecl code ->
      red_expr S C (spec_binding_inst_function_decls L fds (prog_intro_strictness code) bconfig) o1 ->
      red_expr S C (spec_binding_inst_4 ct olf code xs args bconfig L o1) o ->
      red_expr S C (spec_binding_inst_3 ct olf code xs args L) o

  | red_spec_binding_inst_4 : forall bconfig L S0 S C ct olf code xs args o, (* Step 5, continued *)
      red_expr S C (spec_binding_inst_5 ct olf code xs args bconfig L) o ->
      red_expr S0 C (spec_binding_inst_4 ct olf code xs args bconfig L (out_void S)) o

  | red_spec_binding_inst_5 : forall o1 L S C ct olf code xs args bconfig o, (* Step 6 *)
      red_expr S C (spec_env_record_has_binding L "arguments") o1 ->
      red_expr S C (spec_binding_inst_6 ct olf code xs args bconfig L o1) o ->
      red_expr S C (spec_binding_inst_5 ct olf code xs args bconfig L) o

  | red_spec_binding_inst_6_arguments : forall o1 L S0 S C lf code xs args bconfig o, (* Step 7 *)
      red_expr S C (spec_binding_inst_arg_obj lf xs args L (prog_intro_strictness code)) o1 ->
      red_expr S C (spec_binding_inst_7 code bconfig L o1) o ->
      red_expr S0 C (spec_binding_inst_6 codetype_func (Some lf) code xs args bconfig L (out_ter S false)) o

  | red_spec_binding_inst_7 : forall S0 S C code bconfig L o, (* Step 7, continued *)
      red_expr S C (spec_binding_inst_8 code bconfig L) o ->
      red_expr S0 C (spec_binding_inst_7 code bconfig L (out_void S)) o

  | red_spec_binding_inst_6_no_arguments : forall L S0 S C ct olf code xs args bconfig bdefined o, (* Step 7 not needed *)
      ~ (ct = codetype_func /\ bdefined = false) ->
      red_expr S C (spec_binding_inst_8 code bconfig L) o ->
      red_expr S0 C (spec_binding_inst_6 ct olf code xs args bconfig L (out_ter S bdefined)) o

  | red_spec_binding_inst_8 : forall S0 L S C code bconfig o, (* Step 8 *)
      red_expr S C (spec_binding_inst_var_decls L (prog_vardecl code) bconfig (prog_intro_strictness code)) o ->
      red_expr S0 C (spec_binding_inst_8 code bconfig L) o


  (*------------------------------------------------------------*)
  (** 10.6 Arguments Object (returns location to an arguments object) *)

  (* An auxiliary reduction for the MakeArgGetter abstract operation *)

  | red_spec_make_arg_getter : forall xbd bd S C x X o,
     xbd = "return " ++ x ++ ";" ->
     (* Not sure about the strictness. Using 'true' because of strictness equal to true when creating function object. *)
     bd = funcbody_intro (prog_intro true ((element_stat (stat_return (Some (expr_identifier x))))::nil)) xbd ->
     red_expr S C (spec_creating_function_object nil bd X true) o ->
     red_expr S C (spec_make_arg_getter x X) o

  (* An auxiliary reduction for the MakeArgSetter abstract operation *)

  | red_spec_make_arg_setter : forall xparam xbd bd S C x X o,
     xparam = x ++ "_arg" ->
     xbd = x ++ " = " ++ xparam ++ ";" ->
     (* Not sure about the strictness. Using 'true' because of strictness equal to true when creating function object. *)
     bd = funcbody_intro (prog_intro true ((element_stat (expr_assign (expr_identifier x) None (expr_identifier xparam)))::nil)) xbd ->
     red_expr S C (spec_creating_function_object (xparam::nil) bd X true) o ->
     red_expr S C (spec_make_arg_setter x X) o

  (* Arguments Object: Get (returns value) (10.6) *)

  | red_spec_object_get_args_obj : forall lmap S C vthis l x o (y:specret full_descriptor), (* Steps 1 - 2 *)
     object_method object_parameter_map_ S l (Some lmap) ->
     red_spec S C (spec_object_get_own_prop lmap x) y ->
     red_expr S C (spec_args_obj_get_1 vthis l x lmap y) o ->
     red_expr S C (spec_object_get_1 builtin_get_args_obj vthis l x) o

  | red_spec_object_get_args_obj_1_undef : forall o1 S0 S C vthis l x lmap o, (* Step 3 *)
     (* Steps 3 a - c are identical to the steps of 15.3.5.4. *)
     red_expr S0 C (spec_object_get_1 builtin_get_function vthis l x) o ->
     red_expr S C (spec_args_obj_get_1 vthis l x lmap (ret S0 full_descriptor_undef)) o

  | red_spec_object_get_args_obj_1_attrs : forall S0 S C vthis l x lmap A o, (* Step 4 *)
     red_expr S0 C (spec_object_get lmap x) o ->
     red_expr S C (spec_args_obj_get_1 vthis l x lmap (ret S0 (full_descriptor_some A))) o

  (* Arguments Object: DefineOwnProperty (returns bool) (10.6) *)

  | red_spec_object_define_own_prop_args_obj : forall lmap S C l x Desc throw o (y:specret full_descriptor), (* Steps 1 - 2 *)
      object_method object_parameter_map_ S l (Some lmap) ->
      red_spec S C (spec_object_get_own_prop lmap x) y ->
      red_expr S C (spec_args_obj_define_own_prop_1 l x Desc throw lmap y) o ->
      red_expr S C (spec_object_define_own_prop_1 builtin_define_own_prop_args_obj l x Desc throw) o

  | red_spec_object_define_own_prop_args_obj_1 : forall o1 S0 S C l x Desc throw lmap Dmap o, (* Step 3 *)
      red_expr S0 C (spec_object_define_own_prop_1 builtin_define_own_prop_default l x Desc false) o1 ->
      red_expr S0 C (spec_args_obj_define_own_prop_2 l x Desc throw lmap Dmap o1) o ->
      red_expr S C (spec_args_obj_define_own_prop_1 l x Desc throw lmap (ret S0 Dmap)) o

  | red_spec_object_define_own_prop_args_obj_2_false : forall S C l x Desc throw lmap Dmap S' o, (* Step 4 *)
      red_expr S' C (spec_object_define_own_prop_reject throw) o ->
      red_expr S C (spec_args_obj_define_own_prop_2 l x Desc throw lmap Dmap (out_ter S' false)) o

  | red_spec_object_define_own_prop_args_obj_2_true_acc : forall o1 S C l x Desc throw lmap A S' o, (* Step 5 a *)
      descriptor_is_accessor Desc ->
      red_expr S' C (spec_object_delete lmap x false) o1 ->
      red_expr S' C (spec_args_obj_define_own_prop_5 o1) o ->
      red_expr S C (spec_args_obj_define_own_prop_2 l x Desc throw lmap (full_descriptor_some A) (out_ter S' true)) o

  | red_spec_object_define_own_prop_args_obj_2_true_not_acc_some : forall v o1 S C l x Desc throw lmap A S' o, (* Step 5 b i *)
      ~ (descriptor_is_accessor Desc) ->
      descriptor_value Desc = Some v ->
      red_expr S' C (spec_object_put lmap x v throw) o1 ->
      red_expr S' C (spec_args_obj_define_own_prop_3 l x Desc throw lmap o1) o ->
      red_expr S C (spec_args_obj_define_own_prop_2 l x Desc throw lmap (full_descriptor_some A) (out_ter S' true)) o

  | red_spec_object_define_own_prop_args_obj_3 : forall v o1 S C l x Desc throw lmap A S' o, (* Step 5 b i join *)
      red_expr S' C (spec_args_obj_define_own_prop_4 l x Desc throw lmap) o ->
      red_expr S C (spec_args_obj_define_own_prop_3 l x Desc throw lmap (out_void S')) o

  | red_spec_object_define_own_prop_args_obj_2_true_not_acc_none : forall o1 S C l x Desc throw lmap A S' o, (* Step 5 b i else join *)
      ~ (descriptor_is_accessor Desc) ->
      descriptor_value Desc = None ->
      red_expr S' C (spec_args_obj_define_own_prop_4 l x Desc throw lmap) o ->
      red_expr S C (spec_args_obj_define_own_prop_2 l x Desc throw lmap (full_descriptor_some A) (out_ter S' true)) o

  | red_spec_object_define_own_prop_args_obj_4_false : forall o1 S C l x Desc throw lmap o, (* Step 5 b ii *)
      descriptor_writable Desc = Some false ->
      red_expr S C (spec_object_delete lmap x false) o1 ->
      red_expr S C (spec_args_obj_define_own_prop_5 o1) o ->
      red_expr S C (spec_args_obj_define_own_prop_4 l x Desc throw lmap) o

  | red_spec_object_define_own_prop_args_obj_5 : forall S C S' b o, (* Step 5 b ii join *)
      red_expr S' C (spec_args_obj_define_own_prop_6) o ->
      red_expr S C (spec_args_obj_define_own_prop_5 (out_ter S' b)) o

  | red_spec_object_define_own_prop_args_obj_4_not_false : forall S C l x Desc throw lmap o, (* Step 5 b ii else join *)
      descriptor_writable Desc <> Some false ->
      red_expr S C (spec_args_obj_define_own_prop_6) o ->
      red_expr S C (spec_args_obj_define_own_prop_4 l x Desc throw lmap) o

  | red_spec_object_define_own_prop_args_obj_2_true_undef : forall S C l x Desc throw lmap S' o, (* Step 5 else *)
      red_expr S' C (spec_args_obj_define_own_prop_6) o ->
      red_expr S C (spec_args_obj_define_own_prop_2 l x Desc throw lmap full_descriptor_undef (out_ter S' true)) o

  | red_spec_object_define_own_prop_args_obj_6 : forall S C, (* Step 6 *)
    red_expr S C (spec_args_obj_define_own_prop_6) (out_ter S true)

  (** Arguments Object: Delete (10.6) *)

  | red_spec_object_delete_args_obj : forall lmap S C l x throw o (y:specret full_descriptor), (* Steps 1 - 2 *)
      object_method object_parameter_map_ S l (Some lmap) ->
      red_spec S C (spec_object_get_own_prop lmap x) y ->
      red_expr S C (spec_args_obj_delete_1 l x throw lmap y) o ->
      red_expr S C (spec_object_delete_1 builtin_delete_args_obj l x throw) o

  | red_spec_object_delete_args_obj_1 : forall o1 S0 S C l x throw lmap D o, (* Step 3 *)
      red_expr S0 C (spec_object_delete_1 builtin_delete_default l x throw) o1 ->
      red_expr S0 C (spec_args_obj_delete_2 l x throw lmap D o1) o ->
      red_expr S C (spec_args_obj_delete_1 l x throw lmap (ret S0 D)) o

  | red_spec_object_delete_args_obj_2_if : forall o1 S C l x throw lmap A S' o, (* Step 4 a *)
      red_expr S' C (spec_object_delete lmap x false) o1 ->
      red_expr S' C (spec_args_obj_delete_3 o1) o ->
      red_expr S C (spec_args_obj_delete_2 l x throw lmap (full_descriptor_some A) (out_ter S' true)) o

  | red_spec_object_delete_args_obj_3 : forall S C S' b o, (* Step 4 join *)
      red_expr S' C (spec_args_obj_delete_4 true) o ->
      red_expr S C (spec_args_obj_delete_3 (out_ter S' b)) o

  | red_spec_object_delete_args_obj_2_else : forall S C l x throw lmap D S' b o, (* Step 4 else *)
      b = false \/ D = full_descriptor_undef ->
      red_expr S' C (spec_args_obj_delete_4 b) o ->
      red_expr S C (spec_args_obj_delete_2 l x throw lmap D (out_ter S' b)) o

  | red_spec_object_delete_args_obj_4 : forall S C b, (* Step 5 *)
      red_expr S C (spec_args_obj_delete_4 b) (out_ter S b)

  (* An auxiliary reduction 'spec_arguments_object_map' for steps 8-12 of Arguments Object (10.6) *)

  | red_spec_arguments_object_map : forall o1 S C l xs args X str o, (* Step 8 *)
      red_expr S C (spec_construct_prealloc prealloc_object nil) o1 ->
      red_expr S C (spec_arguments_object_map_1 l xs args X str o1) o ->
      red_expr S C (spec_arguments_object_map l xs args X str) o

  | red_spec_arguments_object_map_1 : forall S' S C l xs args X str lmap o, (* Step 9 and 10 *)
      red_expr S' C (spec_arguments_object_map_2 l xs args X str lmap nil (length args - 1)) o ->
      red_expr S C (spec_arguments_object_map_1 l xs args X str (out_ter S' lmap)) o

  | red_spec_arguments_object_map_2_negative : forall S C l xs args X str lmap xsmap k o, (* Step 11 *)
      k < 0 ->
      red_expr S C (spec_arguments_object_map_8 l lmap xsmap) o ->
      red_expr S C (spec_arguments_object_map_2 l xs args X str lmap xsmap k) o

  | red_spec_arguments_object_map_2_positive : forall A o1 S C l xs args X str lmap xsmap k v o, (* Step 11 a-b *)
      ZNth k args v ->
      A = attributes_data_intro_all_true v ->
      red_expr S C (spec_object_define_own_prop l (convert_prim_to_string k) A false) o1 ->
      red_expr S C (spec_arguments_object_map_3 l xs args X str lmap xsmap k o1) o ->
      red_expr S C (spec_arguments_object_map_2 l xs args X str lmap xsmap k) o

  | red_spec_arguments_object_map_3_next : forall S C l xs args X str lmap xsmap k S' b o,  (* Step 11 c next, d *)
      k >= length xs ->
      red_expr S' C (spec_arguments_object_map_2 l xs args X str lmap xsmap (k - 1)) o ->
      red_expr S C (spec_arguments_object_map_3 l xs args X str lmap xsmap k (out_ter S' b)) o

  | red_spec_arguments_object_map_3_cont_next : forall x S C l xs args X str lmap xsmap k S' b o,   (* Step 11 c i, ii next, d *)
      ZNth k xs x ->
      str = true \/ Mem x xsmap ->
      red_expr S' C (spec_arguments_object_map_2 l xs args X str lmap xsmap (k - 1)) o ->
      red_expr S C (spec_arguments_object_map_3 l xs args X str lmap xsmap k (out_ter S' b)) o

  | red_spec_arguments_object_map_3_cont_cont : forall x S C l xs args X str lmap xsmap k S' b o,  (* Step 11 c i, ii continue *)
      ZNth k xs x ->
      str = false /\ ~ (Mem x xsmap) ->
      red_expr S' C (spec_arguments_object_map_4 l xs args X str lmap xsmap k x) o ->
      red_expr S C (spec_arguments_object_map_3 l xs args X str lmap xsmap k (out_ter S' b)) o

  | red_spec_arguments_object_map_4 : forall o1 S C l xs args X str lmap xsmap k x o,  (* Step 11 c ii 1 - 2 *)
      red_expr S C (spec_make_arg_getter x X) o1 ->
      red_expr S C (spec_arguments_object_map_5 l xs args X str lmap (x::xsmap) k x o1) o ->
      red_expr S C (spec_arguments_object_map_4 l xs args X str lmap xsmap k x) o

  | red_spec_arguments_object_map_5 : forall o1 S C l xs args X str lmap xsmap k x S' lgetter o,  (* Step 11 c ii 3 *)
      red_expr S' C (spec_make_arg_setter x X) o1 ->
      red_expr S' C (spec_arguments_object_map_6 l xs args X str lmap xsmap k lgetter o1) o ->
      red_expr S C (spec_arguments_object_map_5 l xs args X str lmap xsmap k x (out_ter S' lgetter)) o

  | red_spec_arguments_object_map_6 : forall A o1 S C l xs args X str lmap xsmap k lgetter S' lsetter o,  (* Step 11 c ii 4 *)
      A = attributes_accessor_intro (value_object lgetter) (value_object lsetter) false true ->
      red_expr S' C (spec_object_define_own_prop lmap (convert_prim_to_string k) A false) o1 ->
      red_expr S' C (spec_arguments_object_map_7 l xs args X str lmap xsmap k o1) o ->
      red_expr S C (spec_arguments_object_map_6 l xs args X str lmap xsmap k lgetter (out_ter S' lsetter)) o

  | red_spec_arguments_object_map_7 : forall S C l xs args X str lmap xsmap k S' b o,  (* Step 11 d loop *)
      red_expr S' C (spec_arguments_object_map_2 l xs args X str lmap xsmap (k - 1)) o ->
      red_expr S C (spec_arguments_object_map_7 l xs args X str lmap xsmap k (out_ter S' b)) o

  | red_spec_arguments_object_map_8_cons : forall O O' S C l lmap xsmap S',  (* Step 12 not empty *)
      xsmap <> nil ->
      object_binds S l O ->
      O' = object_for_args_object O lmap builtin_get_args_obj builtin_get_own_prop_args_obj builtin_define_own_prop_args_obj builtin_delete_args_obj ->
      S' = object_write S l O' ->
      red_expr S C (spec_arguments_object_map_8 l lmap xsmap) (out_void S')

  | red_spec_arguments_object_map_8_nil : forall S C l lmap,  (* Step 12 empty *)
      red_expr S C (spec_arguments_object_map_8 l lmap nil) (out_void S)

  (* Arguments Object: main reduction rules (10.6) *)

  | red_spec_create_arguments_object : forall O l S' A o1 S C lf xs args X str o, (* Steps 2 - 4, 6, 7 *)
      (* The spec does not say anything about [[Extensible]] property that all objects must have.
         Since new properties are defined for this object, "true" is used for [[Extensible]]. *)
      O = object_new prealloc_object_proto "Arguments" ->
      (l, S') = object_alloc S O ->
      A = attributes_data_intro (JsNumber.of_int (length args)) true false true ->
      red_expr S' C (spec_object_define_own_prop l "length" A false) o1 ->
      red_expr S' C (spec_create_arguments_object_1 lf xs args X str l o1) o ->
      red_expr S C (spec_create_arguments_object lf xs args X str) o

  | red_spec_create_arguments_object_1 : forall o1 S C lf xs args X str l S' b o, (* Steps 8 - 12 *)
      red_expr S' C (spec_arguments_object_map l xs args X str) o1 ->
      red_expr S' C (spec_create_arguments_object_2 lf str l o1) o ->
      red_expr S C (spec_create_arguments_object_1 lf xs args X str l (out_ter S' b)) o

  | red_spec_create_arguments_object_2_non_strict : forall A o1 S C lf l S' o, (* Step 13 *)
      A = attributes_data_intro (value_object lf) true false true ->
      red_expr S' C (spec_object_define_own_prop l "callee" A false) o1 ->
      red_expr S' C (spec_create_arguments_object_4 l o1) o ->
      red_expr S C (spec_create_arguments_object_2 lf false l (out_void S')) o

  | red_spec_create_arguments_object_2_strict : forall vthrower A o1 S C lf l S' o, (* Step 14 a-b *)
      vthrower = value_object prealloc_throw_type_error ->
      A = attributes_accessor_intro vthrower vthrower false false ->
      red_expr S' C (spec_object_define_own_prop l "caller" A false) o1 ->
      red_expr S' C (spec_create_arguments_object_3 l vthrower A o1) o ->
      red_expr S C (spec_create_arguments_object_2 lf true l (out_void S')) o

   | red_spec_create_arguments_object_3 : forall o1 S C l vthrower A S' b o, (* Step 14 c *)
      red_expr S' C (spec_object_define_own_prop l "callee" A false) o1 ->
      red_expr S' C (spec_create_arguments_object_4 l o1) o ->
      red_expr S C (spec_create_arguments_object_3 l vthrower A (out_ter S' b)) o

   | red_spec_create_arguments_object_4 : forall S C l S' b l, (* Step 15 *)
      red_expr S C (spec_create_arguments_object_4 l (out_ter S' b)) (out_ter S' l)


  (*------------------------------------------------------------*)
  (** Function objects (13.2) *)

  (** Auxiliary reduction for creating function object: (13.2)
      steps for creating the prototype object (Steps 16-18) *)

  | red_spec_creating_function_object_proto : forall S C l o1 o, (* Step 16 *)
      red_expr S C (spec_construct_prealloc prealloc_object nil) o1 ->
      red_expr S C (spec_creating_function_object_proto_1 l o1) o ->
      red_expr S C (spec_creating_function_object_proto l) o

  | red_spec_creating_function_object_proto_1 : forall S0 S C l lproto o1 o, (* Step 17 *)
      let A := attributes_data_intro (value_object l) true false true in
      red_expr S C (spec_object_define_own_prop lproto "constructor" A false) o1 ->
      red_expr S C (spec_creating_function_object_proto_2 l lproto o1) o ->
      red_expr S0 C (spec_creating_function_object_proto_1 l (out_ter S lproto)) o

   | red_spec_creating_function_object_proto_2 : forall S0 S C l lproto b o, (* Step 18 *)
      let A := attributes_data_intro (value_object lproto) true false false in
      red_expr S C (spec_object_define_own_prop l "prototype" A false) o ->
      red_expr S0 C (spec_creating_function_object_proto_2 l lproto (out_ter S b)) o

  (** Creating function object (returns object) (13.2) *)

  | red_spec_creating_function_object : forall S C S' O O1 O2 O3 A l names bd X str o1 o, (* Steps 1-15 *)
      O = object_new prealloc_function_proto "Function" -> (* Steps 1-4 & 13 *)
      O1 = object_with_get O builtin_get_function -> (* Step 5 *)
      O2 = object_with_invokation O1 (* Steps 6 - 8 *)
        (Some construct_default)
        (Some call_default)
        (Some builtin_has_instance_function) ->
      O3 = object_with_details O2 (Some X) (Some names) (Some bd) None None None None -> (* Steps 9-12 *)
      (l, S') = object_alloc S O3 ->
      A = attributes_data_intro (JsNumber.of_int (length names)) false false false ->
      red_expr S' C (spec_object_define_own_prop l "length" A false) o1 ->
      red_expr S' C (spec_creating_function_object_1 str l o1) o ->
      red_expr S C (spec_creating_function_object names bd X str) o

   | red_spec_creating_function_object_1 : forall S0 S C str l (b:bool) o1 o, (* Steps 16-18 *)
      red_expr S C (spec_creating_function_object_proto l) o1 ->
      red_expr S C (spec_creating_function_object_2 str l o1) o ->
      red_expr S0 C (spec_creating_function_object_1 str l (out_ter S b)) o

   | red_spec_creating_function_object_2_not_strict : forall S0 S C l b, (* Step 20 *)
      red_expr S0 C (spec_creating_function_object_2 false l (out_ter S b)) (out_ter S l)

   | red_spec_creating_function_object_2_strict : forall S0 S C vthrower A l b o1 o, (* Step 19.b *)
      vthrower = value_object prealloc_throw_type_error ->
      A = attributes_accessor_intro vthrower vthrower false false ->
      red_expr S C (spec_object_define_own_prop l "caller" A false) o1 ->
      red_expr S C (spec_creating_function_object_3 l o1) o ->
      red_expr S0 C (spec_creating_function_object_2 true l (out_ter S b)) o

  | red_spec_creating_function_object_3 : forall S0 S C vthrower A l b o1 o, (* Step 19.c *)
      vthrower = value_object prealloc_throw_type_error ->
      A = attributes_accessor_intro vthrower vthrower false false ->
      red_expr S C (spec_object_define_own_prop l "arguments" A false) o1 ->
      red_expr S C (spec_creating_function_object_4 l o1) o ->
      red_expr S0 C (spec_creating_function_object_3 l (out_ter S b)) o

  | red_spec_creating_function_object_4 : forall S0 S C l b, (* Step 20 *)
      red_expr S0 C (spec_creating_function_object_4 l (out_ter S b)) (out_ter S l)

  (** Function calls for regular functions  (13.2.1)
      -- See also [abort_intercepted_expr] for step 5. *)

  | red_spec_call_1_default : forall S C l this args o,
      red_expr S C (spec_call_default l this args) o ->
      red_expr S C (spec_call_1 call_default l this args) o

  | red_spec_call_default : forall S C l this args o, (* Step 1, Step 3 implicit *)
      red_expr S C (spec_entering_func_code l this args (spec_call_default_1 l)) o ->
      red_expr S C (spec_call_default l this args) o

  | red_spec_call_default_1 : forall S C l bdo o, (* Step 2, get code *)
      object_method object_code_ S l bdo ->
      red_expr S C (spec_call_default_2 bdo) o ->
      red_expr S C (spec_call_default_1 l) o

  | red_spec_call_default_2_body : forall S C bd o1 o, (* Step 2, non-empty code *)
      ~ (funcbody_empty bd) ->
      red_prog S C (funcbody_prog bd) o1 ->
      red_expr S C (spec_call_default_3 o1) o ->
      red_expr S C (spec_call_default_2 (Some bd)) o

  | red_spec_call_default_2_empty_body : forall S C l bdo o, (* Step 2, empty code *)
      (match bdo with | None => True | Some bd => funcbody_empty bd end) ->
      red_expr S C (spec_call_default_3 (out_ter S (res_normal undef))) o ->
      red_expr S C (spec_call_default_2 bdo) o

  | red_spec_call_default_3_return : forall S0 S C rv, (* Step 5 (Step 4 done by abort rule) *)
      red_expr S0 C (spec_call_default_3 (out_ter S (res_return rv))) (out_ter S rv)
         (* LATER: can we make it v instead of rv ? *)

  | red_spec_call_default_3_normal : forall S0 S C rv, (* Step 6 *)
      red_expr S0 C (spec_call_default_3 (out_ter S (res_normal rv))) (out_ter S undef)
      (* LATER: can we make it v instead of rv ? *)

  (** Constructor for regular functions  (13.2.2) *)

  | red_spec_construct_1_default : forall S C l args o,
      red_expr S C (spec_construct_default l args) o ->
      red_expr S C (spec_construct_1 construct_default l args) o

  | red_spec_construct_default : forall S C l args o1 o, (* Step 5 *)
      red_expr S C (spec_object_get l "prototype") o1 ->
      red_expr S C (spec_construct_default_1 l args o1) o ->
      red_expr S C (spec_construct_default l args) o

  | red_spec_construct_default_1 : forall S0 S S' C l' vproto O l args v o1 o,
      vproto = (If (type_of v) = type_object then v else prealloc_object_proto) -> (* Step 6-7 *)
      O = object_new vproto "Object" -> (* Step 1-4 *)
      (l', S') = object_alloc S O ->
      red_expr S' C (spec_call l (value_object l') args) o1 -> (* Step 8*)
      red_expr S' C (spec_construct_default_2 l' o1) o ->
      red_expr S0 C (spec_construct_default_1 l args (out_ter S v)) o

  | red_spec_function_construct_2 : forall S0 S C l' v v', (* Step 9-10 *)
      v' = (If (type_of v = type_object) then v else l') ->
      red_expr S0 C (spec_construct_default_2 l' (out_ter S v)) (out_ter S v')
      (* Note: exceptions get propagated automatically *)

  (* LATER: 13.2.3 : throwtypeerror function object *)


 (*------------------------------------------------------------*)

(* TODO: what is this?
      let A := attributes_data_intro (JsNumber.of_int (length names)) false false false in
      red_expr S' C (spec_object_define_own_prop l "length" A false) o1 ->
      red_expr S' C (spec_creating_function_object_proto (spec_creating_function_object_1 str l) l o1) o ->
*)

  (** Shortcut: creates a new function object in the given execution context *)
  | red_spec_create_new_function_in : forall S C args bd o,
      red_expr S C (spec_creating_function_object args bd (execution_ctx_lexical_env C) (execution_ctx_strict C)) o ->
      red_expr S C (spec_create_new_function_in C args bd) o

(*------------------------------------------------------------*)
(** ** Operations on property descriptors (8.10) *)

  (**  FromPropertyDescriptor ( Desc ) - return Object (8.10.4) *)

  | red_spec_from_descriptor_undef : forall S0 S C, (* step 1 *)
      red_expr S0 C (spec_from_descriptor (ret S full_descriptor_undef)) (out_ter S undef)

  | red_spec_from_descriptor_some : forall S0 S C A o o1, (* step 2 *)
      red_expr S C (spec_construct_prealloc prealloc_object nil) o1 ->
      red_expr S C (spec_from_descriptor_1 A o1) o ->
      red_expr S0 C (spec_from_descriptor (ret S (full_descriptor_some A))) o

  | red_spec_from_descriptor_1_data : forall S0 S C Ad A' l o o1, (* step 3.a *)
      A' = attributes_data_intro_all_true (attributes_data_value Ad) ->
      red_expr S C (spec_object_define_own_prop l "value" (descriptor_of_attributes A') throw_false) o1 ->
      red_expr S C (spec_from_descriptor_2 l Ad o1) o ->
      red_expr S0 C (spec_from_descriptor_1 (attributes_data_of Ad) (out_ter S l)) o

  | red_spec_from_descriptor_2_data : forall S0 S C Ad A' l b o o1, (* step 3.b *)
      A' = attributes_data_intro_all_true (attributes_data_writable Ad) ->
      red_expr S C (spec_object_define_own_prop l "writable" (descriptor_of_attributes A') throw_false) o1 ->
      red_expr S C (spec_from_descriptor_4 l Ad o1) o ->
      red_expr S0 C (spec_from_descriptor_2 l Ad (out_ter S b)) o

  | red_spec_from_descriptor_1_accessor : forall S0 S C Aa A' l o o1, (* step 4.a *)
      A' = attributes_data_intro_all_true (attributes_accessor_get Aa) ->
      red_expr S C (spec_object_define_own_prop l "get" (descriptor_of_attributes A') throw_false) o1 ->
      red_expr S C (spec_from_descriptor_3 l Aa o1) o ->
      red_expr S0 C (spec_from_descriptor_1 (attributes_accessor_of Aa) (out_ter S l)) o

  | red_spec_from_descriptor_3_accessor : forall S0 S C Aa A' l b o o1, (* step 4.b *)
      A' = attributes_data_intro_all_true (attributes_accessor_set Aa) ->
      red_expr S C (spec_object_define_own_prop l "set" (descriptor_of_attributes A') throw_false) o1 ->
      red_expr S C (spec_from_descriptor_4 l Aa o1) o ->
      red_expr S0 C (spec_from_descriptor_3 l Aa (out_ter S b)) o

  | red_spec_from_descriptor_4 : forall S0 S C A A' l b o o1, (* step 5 *)
      A' = attributes_data_intro_all_true (attributes_enumerable A) ->
      red_expr S C (spec_object_define_own_prop l "enumerable" (descriptor_of_attributes A') throw_false) o1 ->
      red_expr S C (spec_from_descriptor_5 l A o1) o ->
      red_expr S0 C (spec_from_descriptor_4 l A (out_ter S b)) o

  | red_spec_from_descriptor_5 : forall S0 S C A A' l b o o1, (* step 6 *)
      A' = attributes_data_intro_all_true (attributes_configurable A) ->
      red_expr S C (spec_object_define_own_prop l "configurable" (descriptor_of_attributes A') throw_false) o1 ->
      red_expr S C (spec_from_descriptor_6 l o1) o ->
      red_expr S0 C (spec_from_descriptor_5 l A (out_ter S b)) o

  | red_spec_from_descriptor_6 : forall S0 S C l b, (* step 7 *)
      red_expr S0 C (spec_from_descriptor_6 l (out_ter S b)) (out_ter S l)


(**************************************************************)
(** ** Reduction rules for builtin functions *)

  (** Call to the [[ThrowTypeError]] Function Object  (13.2.3) *)

  | red_spec_call_throw_type_error : forall S C o vthis args,
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (spec_call_prealloc prealloc_throw_type_error vthis args) o


(*------------------------------------------------------------*)
(** ** Global object builtin functions (15.1) *)

  (** Calling eval as a function *)

  | red_spec_call_prealloc_global_eval : forall S C o vthis args,
      red_expr S C (spec_call_global_eval false args) o ->
      red_expr S C (spec_call_prealloc prealloc_global_eval vthis args) o

  (** Eval (returns value)  (15.1.2) *)

  | red_spec_call_global_eval : forall S C bdirect args v o,
      arguments_from args (v::nil) ->
      red_expr S C (spec_call_global_eval_1 bdirect v) o ->
      red_expr S C (spec_call_global_eval bdirect args) o

  | red_spec_call_global_eval_1_not_string : forall S C bdirect v, (* Step 1 *)
      type_of v <> type_string ->
      red_expr S C (spec_call_global_eval_1 bdirect v) (out_ter S v)

  | red_spec_call_global_eval_1_string_not_parse : forall s S C bdirect o, (* Step 2 *)
      parse s None ->
      red_expr S C (spec_error native_error_syntax) o ->
      red_expr S C (spec_call_global_eval_1 bdirect s) o

  | red_spec_call_global_eval_1_string_parse : forall s p S C bdirect o, (* Step 3 and 5 *)
      parse s (Some p) ->
      red_expr S C (spec_entering_eval_code bdirect (funcbody_intro p s) (spec_call_global_eval_2 p)) o ->
      red_expr S C (spec_call_global_eval_1 bdirect s) o

  | red_spec_call_global_eval_2 : forall o1 S C p o, (* Step 4 *)
      red_prog S C p o1 ->
      red_expr S C (spec_call_global_eval_3 o1) o ->
      red_expr S C (spec_call_global_eval_2 p) o

  | red_spec_call_global_eval_3_normal_value : forall S0 S C v, (* Step 6 *)
      red_expr S0 C (spec_call_global_eval_3 (out_ter S v)) (out_ter S v)

  | red_spec_call_global_eval_3_normal_empty : forall S0 S C R, (* Step 7 *)
      res_type R = restype_normal ->
      res_value R = resvalue_empty ->
      red_expr S0 C (spec_call_global_eval_3 (out_ter S R)) (out_ter S undef)

  | red_spec_call_global_eval_3_throw : forall S0 S C R, (* Step 8 *)
      res_type R = restype_throw ->
      red_expr S0 C (spec_call_global_eval_3 (out_ter S R)) (out_ter S (res_throw (res_value R)))

  (** IsNaN (returns bool)  (15.1.2.4) *)

  | red_spec_call_global_is_nan : forall S C v o o1 vthis args,
      arguments_from args (v::nil)  ->
      red_expr S C (spec_to_number v) o1 ->
      red_expr S C (spec_call_global_is_nan_1 o1) o ->
      red_expr S C (spec_call_prealloc prealloc_global_is_nan vthis args) o

  | red_spec_call_global_is_nan_1 : forall S S0 C b n,
      b = (If n = JsNumber.nan then true else false) ->
      red_expr S0 C (spec_call_global_is_nan_1 (out_ter S n)) (out_ter S b)

  (** IsFinite (returns bool)  (15.1.5) *)

  | red_spec_call_global_is_finite : forall S C v o o1 vthis args,
      arguments_from args (v::nil)  ->
      red_expr S C (spec_to_number v) o1 ->
      red_expr S C (spec_call_global_is_finite_1 o1) o ->
      red_expr S C (spec_call_prealloc prealloc_global_is_finite vthis args) o

  | red_spec_call_global_is_finite_1 : forall S S0 C b n,
      b = (If (n = JsNumber.nan \/ n = JsNumber.infinity \/ n = JsNumber.neg_infinity) then false else true) ->
      red_expr S0 C (spec_call_global_is_finite_1 (out_ter S n)) (out_ter S b)


(*------------------------------------------------------------*)
(** ** Object builtin functions (15.2) *)

  (** Object([value]) (returns object_loc)  (15.2.1.1)  *)

  | red_spec_call_object_call : forall S C vthis args v o,
      arguments_from args (v::nil) ->
      red_expr S C (spec_call_object_call_1 v) o ->
      red_expr S C (spec_call_prealloc prealloc_object vthis args) o

  | red_spec_call_object_call_1_null_or_undef : forall S C v o,
      (v = null \/ v = undef) ->
      red_expr S C (spec_call_object_new_1 v) o ->
      red_expr S C (spec_call_object_call_1 v) o

  | red_spec_call_object_call_1_other : forall S C v o,
      v <> null /\ v <> undef ->
      red_expr S C (spec_to_object v) o ->
      red_expr S C (spec_call_object_call_1 v) o

  (** new Object([value]) (returns object_loc)  (15.2.2.1) *)

  | red_spec_call_object_new : forall S C args v o,
      arguments_from args (v::nil) ->
      red_expr S C (spec_call_object_new_1 v) o ->
      red_expr S C (spec_construct_prealloc prealloc_object args) o

  | red_spec_call_object_new_1_object : forall S C v,
      type_of v = type_object ->
      red_expr S C (spec_call_object_new_1 v) (out_ter S v)

  | red_spec_call_object_new_1_prim : forall S C v ty o,
      ty = type_of v ->
      (ty = type_string \/ ty = type_bool \/ ty = type_number) ->
      red_expr S C (spec_to_object v) o ->
      red_expr S C (spec_call_object_new_1 v) o

  | red_spec_call_object_new_1_null_or_undef : forall S C v O l S',
      (v = null \/ v = undef) ->
      O = object_new prealloc_object_proto "Object" ->
      (l, S') = object_alloc S O ->
      red_expr S C (spec_call_object_new_1 v) (out_ter S' l)

  (** Object.getPrototypeOf (returns value)  (15.2.3.2) *)

  | red_spec_call_object_get_proto_of : forall S C v r vthis args o,
      arguments_from args (v::nil) ->
      red_expr S C (spec_call_object_get_proto_of_1 v) o ->
      red_expr S C (spec_call_prealloc prealloc_object_get_proto_of vthis args) o

  | red_spec_call_object_get_proto_of_1_not_object : forall S C w o,
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (spec_call_object_get_proto_of_1 w) o

  | red_spec_call_object_get_proto_of_1_object : forall S C l v,
      object_proto S l v ->
      red_expr S C (spec_call_object_get_proto_of_1 l) (out_ter S v)

  (** Object.getOwnPropertyDescriptor (returns object) (15.2.3.3) *)

  | red_spec_call_object_get_own_prop_descriptor : forall S C vo vx o vthis args, (* step 0 *)
      arguments_from args (vo::vx::nil) ->
      red_expr S C (spec_call_object_get_own_prop_descriptor_1 vo vx) o ->
      red_expr S C (spec_call_prealloc prealloc_object_get_own_prop_descriptor vthis args) o

  | red_spec_call_object_get_own_prop_descriptor_1_not_object : forall S C vo vx o, (* step 1 *)
      type_of vo <> type_object ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (spec_call_object_get_own_prop_descriptor_1 vo vx) o

  | red_spec_call_object_get_own_prop_descriptor_1_object : forall S C l vx o o1 , (* step 2 *)
      red_expr S C (spec_to_string vx) o1 ->
      red_expr S C (spec_call_object_get_own_prop_descriptor_2 l o1) o ->
      red_expr S C (spec_call_object_get_own_prop_descriptor_1 l vx) o

  | red_spec_call_object_get_own_prop_descriptor_2 : forall S0 S C l x o (y:specret full_descriptor), (* steps 3 and 4 *)
      red_spec S C (spec_object_get_own_prop l x) y ->
      red_expr S C (spec_from_descriptor y) o ->
      red_expr S0 C (spec_call_object_get_own_prop_descriptor_2 l (out_ter S x)) o

  (* LATER: getOwnPropertyNames (requires Array) *)


  (** Object.create (returns object) (15.2.3.5) *)

  | red_spec_call_object_object_create : forall S C vo vp vthis args o, (* step 0 *)
      arguments_from args (vo::vp::nil) ->
      red_expr S C (spec_call_object_create_1 vo vp) o ->
      red_expr S C (spec_call_prealloc prealloc_object_create vthis args) o

  | red_spec_call_object_object_create_1_not_object : forall S C vo vp o, (* step 1 *)
      type_of vo <> type_object ->
      type_of vo <> type_null ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (spec_call_object_create_1 vo vp) o

  | red_spec_call_object_object_create_1_object : forall S C l vo vp o o1, (* step 2 *)
      red_expr S C (spec_construct_prealloc prealloc_object nil) o1 ->
      red_expr S C (spec_call_object_create_2 o1 vo vp) o ->
      red_expr S C (spec_call_object_create_1 vo vp) o

  | red_spec_call_object_object_create_2 : forall S S0 C l O O' S' vo vp o, (* step 3 *)
      object_binds S l O ->
      O' = object_set_proto O vo ->
      S' = object_write S l O' ->
      red_expr S' C (spec_call_object_create_3 l vp) o ->
      red_expr S0 C (spec_call_object_create_2 (out_ter S l) vo vp) o

  | red_spec_call_object_object_create_3_def : forall S C l vp o, (* step 4 (implicity covering step 5) *)
      vp <> undef ->
      red_expr S C (spec_call_object_define_props_1 l vp) o ->
      red_expr S C (spec_call_object_create_3 l vp) o

  | red_spec_call_object_object_create_3_undef : forall S C l, (* step 5 *)
      red_expr S C (spec_call_object_create_3 l undef) (out_ter S l)

  (** Object.defineProperty (returns object) (15.2.3.6) *)

  | red_spec_call_object_object_define_prop : forall S C vo vx va o vthis args, (* step 0 *)
      arguments_from args (vo::vx::va::nil) ->
      red_expr S C (spec_call_object_define_prop_1 vo vx va) o ->
      red_expr S C (spec_call_prealloc prealloc_object_define_prop vthis args) o

  | red_spec_call_object_object_define_prop_1_not_object : forall S C vo vx va o, (* step 1 *)
      type_of vo <> type_object ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (spec_call_object_define_prop_1 vo vx va) o

  | red_spec_call_object_object_define_prop_1_object : forall S C l vx va o1 o, (* step 2 *)
      red_expr S C (spec_to_string vx) o1 ->
      red_expr S C (spec_call_object_define_prop_2 l o1 va) o ->
      red_expr S C (spec_call_object_define_prop_1 l vx va) o

  | red_spec_call_object_object_define_prop_2 : forall S C l x va o (y: specret descriptor), (* step 3 *)
      red_spec S C (spec_to_descriptor va) y ->
      red_expr S C (spec_call_object_define_prop_3 l x y) o ->
      red_expr S C (spec_call_object_define_prop_2 l (out_ter S x) va) o

  | red_spec_call_object_object_define_prop_3 : forall S S0 C l s Desc o1 o, (* step 4 *)
      red_expr S C (spec_object_define_own_prop l s Desc throw_true) o1 ->
      red_expr S C (spec_call_object_define_prop_4 l o1) o ->
      red_expr S0 C (spec_call_object_define_prop_3 l s (ret S Desc)) o

  | red_spec_call_object_object_define_prop_4 : forall S0 S C l, (* Step 5 *)
      red_expr S0 C (spec_call_object_define_prop_4 l (out_void S)) (out_ter S l)

  (** Object.defineProperties (returns object) (15.2.3.7) *)

  | red_spec_call_object_object_define_props : forall S C vo vp o vthis args, (* step 0 *)
      arguments_from args (vo::vp::nil) ->
      red_expr S C (spec_call_object_define_props_1 vo vp) o ->
      red_expr S C (spec_call_prealloc prealloc_object_define_props vthis args) o

  | red_spec_call_object_object_define_props_1_not_object : forall S C vo vp o, (* step 1 *)
      type_of vo <> type_object ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (spec_call_object_define_props_1 vo vp) o

  | red_spec_call_object_object_define_props_1_object : forall S C l vp o o1, (* step 2 *)
      red_expr S C (spec_to_object vp) o1 ->
      red_expr S C (spec_call_object_define_props_2 o1 l) o ->
      red_expr S C (spec_call_object_define_props_1 l vp) o

  | red_spec_call_object_object_define_props_2 : forall S0 S C l lp xs o o1, (* step 3 and 4 *)
      object_properties_enumerable_keys_as_list S lp xs ->
      red_expr S C (spec_call_object_define_props_3 l lp xs nil) o ->
      red_expr S0 C (spec_call_object_define_props_2 (out_ter S lp) l) o

  | red_spec_call_object_define_props_3_nil : forall S C l lp Descs o, (* step 5 (end loop) *)
      red_expr S C (spec_call_object_define_props_6 l Descs) o ->
      red_expr S C (spec_call_object_define_props_3 l lp nil Descs) o

  | red_spec_call_object_define_props_3_cons : forall S C l lp x xs Descs o o1, (* step 5 and 5.a *)
      red_expr S C (spec_object_get lp x) o1 ->
      red_expr S C (spec_call_object_define_props_4 o1 l lp x xs Descs) o ->
      red_expr S C (spec_call_object_define_props_3 l lp (x::xs) Descs) o

  | red_spec_call_object_define_props_4 : forall S0 S C v l lp o o1 x xs Descs (y:specret attributes), (* step 5.b *)
      red_spec S C (spec_to_descriptor v) y ->
      red_expr S C (spec_call_object_define_props_5 l lp x xs Descs y) o1 ->
      red_expr S0 C (spec_call_object_define_props_4 (out_ter S v) l lp x xs Descs) o

  | red_spec_call_object_define_props_5 : forall S S0 C A l lp o o1 x xs Descs, (* step 5.c *)
      red_expr S C (spec_call_object_define_props_3 l lp xs (Descs++(x,A)::nil)) o ->
      red_expr S0 C (spec_call_object_define_props_5 l lp x xs Descs (ret S A)) o

  | red_spec_call_object_define_props_6_cons : forall S C l x A Descs o1 o , (* step 6 *)
     red_expr S C (spec_object_define_own_prop l x (descriptor_of_attributes A) throw_true) o1 ->
     red_expr S C (spec_call_object_define_props_7 o1 l Descs) o ->
     red_expr S C (spec_call_object_define_props_6 l ((x,A)::Descs)) o

  | red_spec_call_object_define_props_7 : forall S0 S C l Descs b o, (* step 6 (end loop) *)
     red_expr S C (spec_call_object_define_props_6 l Descs) o ->
     red_expr S0 C (spec_call_object_define_props_7 (out_ter S b) l Descs) o

  | red_spec_call_object_define_props_6_nil : forall S C l, (* step 7 *)
      red_expr S C (spec_call_object_define_props_6 l nil) (out_ter S l)

  (** Seal (returns Object) (15.2.3.8) *)

  | red_spec_call_object_seal : forall S C v o vthis args, (* Step 0 *)
      arguments_from args (v::nil) ->
      red_expr S C (spec_call_object_seal_1 v) o ->
      red_expr S C (spec_call_prealloc prealloc_object_seal vthis args) o

  | red_spec_call_object_seal_1_not_object : forall S C v o, (* Step 1 *)
      type_of v <> type_object ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (spec_call_object_seal_1 v) o

  | red_spec_call_object_seal_1_object : forall S C l xs x o, (* Step 2 *)
      object_properties_keys_as_list S l xs ->
      red_expr S C (spec_call_object_seal_2 l xs) o ->
      red_expr S C (spec_call_object_seal_1 l) o

  | red_spec_call_object_seal_2_cons : forall S C l xs x o (y:specret full_descriptor), (* Step 2.a *)
      red_spec S C (spec_object_get_own_prop l x) y ->
      red_expr S C (spec_call_object_seal_3 l x xs y) o ->
      red_expr S C (spec_call_object_seal_2 l (x::xs)) o

  | red_spec_call_object_seal_3 : forall S0 S C l xs x A A' o1 o, (* Step 2.b and 2.c *)
      A' = (If attributes_configurable A then (attributes_with_configurable A false) else A) ->
      red_expr S C (spec_object_define_own_prop l x (descriptor_of_attributes A') throw_true) o1 ->
      red_expr S C (spec_call_object_seal_4 l xs o1) o ->
      red_expr S C (spec_call_object_seal_3 l x xs (ret (T:=full_descriptor) S0 A)) (out_ter S false)

  | red_spec_call_object_seal_4 : forall S0 S C l xs b o, (* Step 2, loop *)
      red_expr S C (spec_call_object_seal_2 l xs) o ->
      red_expr S0 C (spec_call_object_seal_4 l xs (out_ter S b)) o

  | red_spec_call_object_seal_2_nil : forall S S' C l, (* Steps 3 and 4 *)
      object_heap_set_extensible false S l S' ->
      red_expr S C (spec_call_object_seal_2 l nil) (out_ter S' l)

  (** Freeze (returns object) (15.2.3.9) *)

  | red_spec_call_object_freeze : forall S C v o vthis args, (* Step 0 *)
      arguments_from args (v::nil) ->
      red_expr S C (spec_call_object_freeze_1 v) o ->
      red_expr S C (spec_call_prealloc prealloc_object_freeze vthis args) o

  | red_spec_call_object_freeze_1_not_object : forall S C v o, (* Step 1 *)
      type_of v <> type_object ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (spec_call_object_freeze_1 v) o

  | red_spec_call_object_freeze_1_object : forall S C l xs x o, (* Step 2 *)
      object_properties_keys_as_list S l xs ->
      red_expr S C (spec_call_object_freeze_2 l xs) o ->
      red_expr S C (spec_call_object_freeze_1 l) o

  | red_spec_call_object_freeze_2_cons : forall S C l xs x o (y:specret full_descriptor), (* Step 2.a *)
      red_spec S C (spec_object_get_own_prop l x) y ->
      red_expr S C (spec_call_object_freeze_3 l x xs y) o ->
      red_expr S C (spec_call_object_freeze_2 l (x::xs)) o

  | red_spec_call_object_freeze_3 : forall S0 S C A A' xs l x o, (* Step 2.b *)
      A' = match A with
          | attributes_data_of Ad => attributes_data_of (
              If attributes_data_writable Ad
                then (attributes_data_with_writable Ad false)
                else Ad)
          | attributes_accessor_of Aa => attributes_accessor_of Aa
          end ->
      red_expr S C (spec_call_object_freeze_4 l x xs A') o ->
      red_expr S C (spec_call_object_freeze_3 l x xs (ret (T:=full_descriptor) S0 A)) o

  | red_spec_call_object_freeze_4 : forall S C Desc A A' xs l x o1 o, (* Steps 2.c and 2.d *)
      A' = (If attributes_configurable A then (attributes_with_configurable A false) else A) ->
      red_expr S C (spec_object_define_own_prop l x (descriptor_of_attributes A') throw_true) o1 ->
      red_expr S C (spec_call_object_freeze_5 l xs o1) o ->
      red_expr S C (spec_call_object_freeze_4 l x xs A) o

  | red_spec_call_object_freeze_5 : forall S0 S C xs l x b o, (* Step 2, loop *)
      red_expr S C (spec_call_object_freeze_2 l xs) o ->
      red_expr S0 C (spec_call_object_freeze_5 l xs (out_ter S b)) o

  | red_spec_call_object_freeze_2_nil : forall S S' C l b x o, (* Steps 4 and 5 *)
      object_heap_set_extensible false S l S' ->
      red_expr S C (spec_call_object_freeze_2 l nil) (out_ter S' l)

  (** PreventExtensions (returns object)  (15.2.3.10) *)

  | red_spec_call_object_prevent_extensions : forall S C v o vthis args,
      arguments_from args (v::nil) ->
      red_expr S C (spec_call_object_prevent_extensions_1 v) o ->
      red_expr S C (spec_call_prealloc prealloc_object_prevent_extensions vthis args) o

  | red_spec_call_object_prevent_extensions_not_object : forall S C v o,
      type_of v <> type_object ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (spec_call_object_prevent_extensions_1 v) o

  | red_spec_call_object_prevent_extensions_object : forall S S' C O O' l,
      object_binds S l O ->
      O' = object_with_extension O false ->
      S' = object_write S l O' ->
      red_expr S C (spec_call_object_prevent_extensions_1 l) (out_ter S' l)

  (** IsSealed (returns bool)  (15.2.3.11) *)

  | red_spec_call_object_is_sealed : forall S C v o vthis args, (* Step 0 *)
      arguments_from args (v::nil) ->
      red_expr S C (spec_call_object_is_sealed_1 v) o ->
      red_expr S C (spec_call_prealloc prealloc_object_is_sealed vthis args) o

  | red_spec_call_object_is_sealed_1_not_object : forall S C v o, (* Step 1 *)
      type_of v <> type_object ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (spec_call_object_is_sealed_1 v) o

  | red_spec_call_object_is_sealed_1_object : forall S C l xs x o, (* Step 2 *)
      object_properties_keys_as_list S l xs ->
      red_expr S C (spec_call_object_is_sealed_2 l xs) o ->
      red_expr S C (spec_call_object_is_sealed_1 l) o

  | red_spec_call_object_is_sealed_2_cons : forall S C l xs x o (y:specret full_descriptor), (* Step 2.a *)
      red_spec S C (spec_object_get_own_prop l x) y ->
      red_expr S C (spec_call_object_is_sealed_3 l xs y) o ->
      red_expr S C (spec_call_object_is_sealed_2 l (x::xs)) o

  | red_spec_call_object_is_sealed_3_prop_configurable : forall S0 S C A xs l x o, (* Step 2.b, true *)
      attributes_configurable A = true ->
      red_expr S C (spec_call_object_is_sealed_3 l xs (ret (T:=full_descriptor) S0 A)) (out_ter S false)

  | red_spec_call_object_is_sealed_3_prop_not_configurable : forall S0 S C A xs l x o, (* Step 2.b, false *)
      attributes_configurable A = false ->
      red_expr S C (spec_call_object_is_sealed_2 l xs) o ->
      red_expr S C (spec_call_object_is_sealed_3 l xs (ret (T:=full_descriptor) S0 A)) o

  | red_spec_call_object_is_sealed_2_nil : forall S C l b x o, (* Step 3-4 *)
      object_extensible S l b ->
      red_expr S C (spec_call_object_is_sealed_2 l nil) (out_ter S (negb b))

  (** IsFrozen (returns bool)  (15.2.3.12) *)

  | red_spec_call_object_is_frozen : forall S C v o vthis args, (* Step 0 *)
      arguments_from args (v::nil) ->
      red_expr S C (spec_call_object_is_frozen_1 v) o ->
      red_expr S C (spec_call_prealloc prealloc_object_is_frozen vthis args) o

  | red_spec_call_object_is_frozen_1_not_object : forall S C v o, (* Step 1 *)
      type_of v <> type_object ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (spec_call_object_is_frozen_1 v) o

  | red_spec_call_object_is_frozen_1_object : forall S C l xs x o, (* Step 2 *)
      object_properties_keys_as_list S l xs ->
      red_expr S C (spec_call_object_is_frozen_2 l xs) o ->
      red_expr S C (spec_call_object_is_frozen_1 l) o

  | red_spec_call_object_is_frozen_2_cons : forall S C l xs x o (y:specret full_descriptor), (* Step 2.a *)
      red_spec S C (spec_object_get_own_prop l x) y ->
      red_expr S C (spec_call_object_is_frozen_3 l xs y) o ->
      red_expr S C (spec_call_object_is_frozen_2 l (x::xs)) o

  | red_spec_call_object_is_frozen_3_desc_is_data : forall S0 S C A xs l x o, (* Step 2.b, true *)
      attributes_is_data A = true ->
      red_expr S C (spec_call_object_is_frozen_4 l xs A) o ->
      red_expr S C (spec_call_object_is_frozen_3 l xs (ret (T:=full_descriptor) S0 A)) o

  | red_spec_call_object_is_frozen_3_desc_is_not_data : forall S0 S C A xs l x o, (* Step 2.b, false *)
      attributes_is_data A = false ->
      red_expr S C (spec_call_object_is_frozen_5 l xs A) o ->
      red_expr S C (spec_call_object_is_frozen_3 l xs (ret (T:=full_descriptor) S0 A)) o

  | red_spec_call_object_is_frozen_4_prop_is_writable: forall S C A xs l x o, (* Step 2.b.i, true *)
      attributes_writable A = true ->
      red_expr S C (spec_call_object_is_frozen_4 l xs A) (out_ter S false)

  | red_spec_call_object_is_frozen_4_prop_is_not_writable: forall S C A xs l x o, (* Step 2.b.i, false *)
      attributes_writable A = false ->
      red_expr S C (spec_call_object_is_frozen_5 l xs A) o ->
      red_expr S C (spec_call_object_is_frozen_4 l xs A) o

  | red_spec_call_object_is_frozen_5_prop_configurable : forall S C A xs l x o, (* Step 2.c, true *)
      attributes_configurable A = true ->
      red_expr S C (spec_call_object_is_frozen_5 l xs A) (out_ter S false)

  | red_spec_call_object_is_frozen_5_prop_not_configurable : forall S C A xs l x o,  (* Step 2.c, false*)
      attributes_configurable A = false ->
      red_expr S C (spec_call_object_is_frozen_2 l xs) o ->
      red_expr S C (spec_call_object_is_frozen_5 l xs A) o

  | red_spec_call_object_is_frozen_2_nil : forall S C l b x o, (* Steps 3-4 *)
      object_extensible S l b ->
      red_expr S C (spec_call_object_is_frozen_2 l nil) (out_ter S (negb b))

  (** IsExtensible (returns bool)  (15.2.3.13) *)

  | red_spec_call_object_is_extensible : forall S C v o vthis args,
      arguments_from args (v::nil) ->
      red_expr S C (spec_call_object_is_extensible_1 v) o ->
      red_expr S C (spec_call_prealloc prealloc_object_is_extensible vthis args) o

  | red_spec_call_object_is_extensible_1_not_object : forall S C v o,
      type_of v <> type_object ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (spec_call_object_is_extensible_1 v) o

  | red_spec_call_object_is_extensible_1_object : forall S C l b,
      object_extensible S l b ->
      red_expr S C (spec_call_object_is_extensible_1 l) (out_ter S b)

  (** LATER: keys  (similar to getNames) *)

(*------------------------------------------------------------*)
(** ** Object prototype builtin functions (15.2.3) *)

  (** Object.prototype.toString() (returns string)  (15.2.4.2) *)

  | red_spec_call_object_proto_to_string : forall S C vthis args o,
      red_expr S C (spec_call_object_proto_to_string_1 vthis) o ->
      red_expr S C (spec_call_prealloc prealloc_object_proto_to_string vthis args) o

  | red_spec_call_object_proto_to_string_1_undef : forall S C,
      red_expr S C (spec_call_object_proto_to_string_1 undef) (out_ter S "[object Undefined]"%string)

  | red_spec_call_object_proto_to_string_1_null : forall S C,
      red_expr S C (spec_call_object_proto_to_string_1 null) (out_ter S "[object Null]"%string)

  | red_spec_call_object_proto_to_string_1_other : forall S C v o o1,
      ~ (v = null \/ v = undef) ->
      red_expr S C (spec_to_object v) o1 ->
      red_expr S C (spec_call_object_proto_to_string_2 o1) o ->
      red_expr S C (spec_call_object_proto_to_string_1 v) o

  | red_spec_call_object_proto_to_string_2 : forall S0 S C l s sclass,
      object_class S l sclass ->
      s = "[object " ++ sclass ++ "]" ->
      red_expr S0 C (spec_call_object_proto_to_string_2 (out_ter S l)) (out_ter S s)

  (** Object.prototype.valueOf() (returns value)  (15.2.4.4) *)

  | red_spec_call_object_proto_value_of : forall S C vthis args o,
      red_expr S C (spec_to_object vthis) o ->
      red_expr S C (spec_call_prealloc prealloc_object_proto_value_of vthis args) o

  (** Object.prototype.hasOwnProperty() (returns bool)  (15.2.4.5) *)

  | red_spec_call_object_proto_has_own_prop : forall S C v vthis args o o1, (* Step 1 *)
      arguments_from args (v::nil) ->
      red_expr S C (spec_to_string v) o1 ->
      red_expr S C (spec_call_object_proto_has_own_prop_1 o1 vthis) o ->
      red_expr S C (spec_call_prealloc prealloc_object_proto_has_own_prop vthis args) o

  | red_spec_call_object_proto_has_own_prop_1 : forall S S' C vthis s o o1, (* Step 2 *)
      red_expr S' C (spec_to_object vthis) o1 ->
      red_expr S' C (spec_call_object_proto_has_own_prop_2 o1 s) o ->
      red_expr S C (spec_call_object_proto_has_own_prop_1 (out_ter S' s) vthis) o

  | red_spec_call_object_proto_has_own_prop_2 : forall S S' C l s o y, (* Step 3 *)
      red_spec S' C (spec_object_get_own_prop l s) y ->
      red_expr S' C (spec_call_object_proto_has_own_prop_3 y) o ->
      red_expr S C (spec_call_object_proto_has_own_prop_2 (out_ter S' l) s) o

  | red_spec_call_object_proto_has_own_prop_3_undef : forall S S' C, (* Step 4 *)
      red_expr S C (spec_call_object_proto_has_own_prop_3 (ret S' full_descriptor_undef)) (out_ter S' false)

  | red_spec_call_object_proto_has_own_prop_3_not_undef : forall S S' C A, (* Step 5 *)
      red_expr S C (spec_call_object_proto_has_own_prop_3 (ret (T := full_descriptor) S' A)) (out_ter S' true)

   (** Object.prototype.isPrototypeOf() (returns bool)  (15.2.4.6) *)

  | red_spec_call_object_proto_is_prototype_of_not_object : forall S C vthis args v o, (* Step 0 *)
      arguments_from args (v::nil) ->
      red_expr S C (spec_call_object_proto_is_prototype_of_2_1 v vthis) o ->
      red_expr S C (spec_call_prealloc prealloc_object_proto_is_prototype_of vthis args) o

  | red_spec_call_object_proto_is_prototype_of_1_not_object : forall S C v vthis, (* Step 1 *)
      type_of v <> type_object ->
      red_expr S C (spec_call_object_proto_is_prototype_of_2_1 v vthis) (out_ter S false)

  | red_spec_call_object_proto_is_prototype_of_1_object : forall S C l vthis o1 o, (* Step 2 *)
      red_expr S C (spec_to_object vthis) o1 ->
      red_expr S C (spec_call_object_proto_is_prototype_of_2_2 o1 l) o ->
      red_expr S C (spec_call_object_proto_is_prototype_of_2_1 l vthis) o

  | red_spec_call_object_proto_is_prototype_of_2 : forall S0 S C l lthis o,
      red_expr S C (spec_call_object_proto_is_prototype_of_2_3 lthis l) o ->
      red_expr S0 C (spec_call_object_proto_is_prototype_of_2_2 (out_ter S lthis) l) o

  | red_spec_call_object_proto_is_prototype_of_3 : forall S C l lthis vproto o, (* Step 3.a *)
      object_proto S l vproto ->
      red_expr S C (spec_call_object_proto_is_prototype_of_2_4 lthis vproto) o ->
      red_expr S C (spec_call_object_proto_is_prototype_of_2_3 lthis l) o

  | red_spec_call_object_proto_is_prototype_of_4_null : forall S C lthis, (* Step 3.b *)
      red_expr S C (spec_call_object_proto_is_prototype_of_2_4 lthis null) (out_ter S false)

  | red_spec_call_object_proto_is_prototype_of_4_equal : forall S C lthis, (* Step 3.c *)
      red_expr S C (spec_call_object_proto_is_prototype_of_2_4 lthis lthis) (out_ter S true)

  | red_spec_call_object_proto_is_prototype_of_4_not_equal : forall S C l lthis lproto o, (* Look back to step 3 *)
      (* Note: we implicitly enforce the fact that a proto can only be a location or null *)
      lproto <> lthis ->
      red_expr S C (spec_call_object_proto_is_prototype_of_2_3 lthis lproto) o ->
      red_expr S C (spec_call_object_proto_is_prototype_of_2_4 lthis lproto) o

  (** Object.prototype.propertyIsEnumerable(V) (returns bool)  (15.2.4.7) *)

  | red_spec_call_object_proto_prop_is_enumerable : forall S C v o vthis args,
      arguments_from args (v::nil)  ->
      red_expr S C (spec_call_object_proto_prop_is_enumerable_1 v vthis) o ->
      red_expr S C (spec_call_prealloc prealloc_object_proto_prop_is_enumerable vthis args) o

  | red_spec_call_object_proto_prop_is_enumerable_1 : forall S C v vthis o o1,
      red_expr S C (spec_to_string v) o1 ->
      red_expr S C (spec_call_object_proto_prop_is_enumerable_2 vthis o1) o ->
      red_expr S C (spec_call_object_proto_prop_is_enumerable_1 v vthis) o

  | red_spec_call_object_proto_prop_is_enumerable_2 : forall S S' C vthis s o o1,
      red_expr S' C (spec_to_object vthis) o1 ->
      red_expr S' C (spec_call_object_proto_prop_is_enumerable_3 o1 s) o ->
      red_expr S C (spec_call_object_proto_prop_is_enumerable_2 vthis (out_ter S' s)) o

  | red_spec_call_object_proto_prop_is_enumerable_3 : forall S S' C l x o (y:specret full_descriptor),
      red_spec S' C (spec_object_get_own_prop l x) y ->
      red_expr S' C (spec_call_object_proto_prop_is_enumerable_4 y) o ->
      red_expr S C (spec_call_object_proto_prop_is_enumerable_3 (out_ter S' l) x) o

  | red_spec_call_object_proto_prop_is_enumerable_4_undef : forall S0 S C,
      red_expr S C (spec_call_object_proto_prop_is_enumerable_4 (ret (T:=full_descriptor) S0 full_descriptor_undef)) (out_ter S0 false)

  | red_spec_call_object_proto_prop_is_enumerable_4_not_undef : forall S0 S C A b,
      b = attributes_enumerable A ->
      red_expr S C (spec_call_object_proto_prop_is_enumerable_4 (ret (T:=full_descriptor) S0 A)) (out_ter S0 b)

  (*------------------------------------------------------------*)
  (** ** Function builtin functions *)

  (** Function.prototype() -- always return undefined  (15.3.4) *)

  | red_spec_call_function_proto_invoked : forall S C vthis args,
      red_expr S C (spec_call_prealloc prealloc_function_proto vthis args) (out_ter S undef)

  (** Function: Get  (returns value) (15.3.5.4) *)

  | red_spec_object_get_1_function : forall S C vthis l x o1 o, (* Step 1 *)
      red_expr S C (spec_object_get_1 builtin_get_default vthis l x) o1 ->
      red_expr S C (spec_function_get_1 l x o1) o ->
      red_expr S C (spec_object_get_1 builtin_get_function vthis l x) o

  | red_spec_function_get_1_error : forall S0 S C l x v o, (* Step 2 *)
      spec_function_get_error_case S x v ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S0 C (spec_function_get_1 l x (out_ter S v)) o

  | red_spec_function_get_1_normal : forall S0 S C l x v, (* Step 3 *)
      ~ (spec_function_get_error_case S x v) ->
      red_expr S0 C (spec_function_get_1 l x (out_ter S v)) (out_ter S v)

   (** Function: HasInstance  (returns bool)  (15.3.5.3) *)

   | red_spec_object_has_instance_1_function_prim : forall S C l w, (* Step 1 *)
       red_expr S C (spec_object_has_instance_1 builtin_has_instance_function l (value_prim w)) (out_ter S false)

   | red_spec_object_has_instance_1_function_object : forall o1 S C l lv o, (* Step 2 *)
       red_expr S C (spec_object_get l "prototype") o1 ->
       red_expr S C (spec_function_has_instance_1 lv o1) o ->
       red_expr S C (spec_object_has_instance_1 builtin_has_instance_function l (value_object lv)) o

   | red_spec_function_has_instance_1_prim : forall S0 S C lv v o, (* Step 3 *)
       type_of v <> type_object ->
       red_expr S C (spec_error native_error_type) o ->
       red_expr S0 C (spec_function_has_instance_1 lv (out_ter S v)) o

   | red_spec_function_has_instance_1_object : forall S0 S C lv lo o, (* Step 4 *)
       red_expr S C (spec_function_has_instance_2 lo lv) o ->
       red_expr S0 C (spec_function_has_instance_1 lv (out_ter S (value_object lo))) o

   | red_spec_function_has_instance_2 : forall S C lo lv vproto o, (* Step 4a *)
       object_proto S lv vproto ->
       red_expr S C (spec_function_has_instance_3 lo vproto) o ->
       red_expr S C (spec_function_has_instance_2 lo lv) o

   | red_spec_function_has_instance_3_null : forall S C lo, (* Step 4b *)
       red_expr S C (spec_function_has_instance_3 lo null) (out_ter S false)

   | red_spec_function_has_instance_3_eq : forall S C lo lv, (* Step 4c *)
       lv = lo ->
       red_expr S C (spec_function_has_instance_3 lo lv) (out_ter S true)

   | red_spec_function_has_instance_3_neq : forall S C lo lv o, (* Step 4 (repeat) *)
       lv <> lo ->
       red_expr S C (spec_function_has_instance_2 lo lv) o ->
       red_expr S C (spec_function_has_instance_3 lo lv) o

  (*------------------------------------------------------------*)
  (** ** Function built using Function.prototype.bind (15.3.4.5) *)

   (** LATER: HasInstance, call, construct  *)

  (*------------------------------------------------------------*)
  (** ** Array builtin functions *)

  (** new Array() (returns object_loc)  (15.4.2.1) *)
  (** new Array(value, [value]) (returns object_loc)  (15.4.2.1) *)
  (* This constructor only applies if there are zero arguments or at least two
  arguments. Otherwise the spec mandates the use of 15.4.2.2. *)

  | red_spec_call_array_new_no_args : forall S C args o,
      args = nil ->
      red_expr S C (spec_call_array_new_1 args) o ->
      red_expr S C (spec_construct_prealloc prealloc_array args) o

  | red_spec_call_array_new_multiple_args : forall S C args v1 v2 vs o,
      args = v1::v2::vs ->
      red_expr S C (spec_call_array_new_1 args) o ->
      red_expr S C (spec_construct_prealloc prealloc_array args) o

  | red_spec_call_array_new_1 : forall S S' C args O l o,
      O = object_new prealloc_array_proto "Array" ->
      (l, S') = object_alloc S O ->
      red_expr S' C (spec_call_array_new_2 l args 0) o ->
      red_expr S C (spec_call_array_new_1 args) o

  | red_spec_call_array_new_2_nonempty: forall S S' C O l A v vs ilen o,
      object_set_property S l (JsNumber.to_string (JsNumber.of_int ilen)) (attributes_data_intro v true true true) S' ->
      red_expr S' C (spec_call_array_new_2 l vs (ilen + 1)) o ->
      red_expr S C (spec_call_array_new_2 l (v::vs) ilen) o

  | red_spec_call_array_new_2_empty: forall S S' C O l ilen o,
      object_set_property S l "length" (attributes_data_intro (JsNumber.of_int ilen) true true true) S' ->
      red_expr S C (spec_call_array_new_2 l nil ilen) (out_ter S' l)

  (** Array.prototype.pop() (returns value)  (15.4.4.6) *)

  | red_spec_call_array_proto_pop : forall S C vthis l o o1 args, (* 1 *)
      red_expr S C (spec_to_object vthis) o1 ->
      red_expr S C (spec_call_array_proto_pop_1 o1) o ->
      red_expr S C (spec_call_prealloc prealloc_array_proto_pop vthis args) o

  | red_spec_call_array_proto_pop_1 : forall S0 S C l o o1, (* 2 *)
      red_expr S C (spec_object_get l "length") o1 ->
      red_expr S C (spec_call_array_proto_pop_2 l o1) o ->
      red_expr S0 C (spec_call_array_proto_pop_1 (out_ter S l)) o

  | red_spec_call_array_proto_pop_2 : forall S0 S C l vlen o y, (* 3 *)
      red_spec S C (spec_to_uint32 vlen) y ->
      red_expr S C (spec_call_array_proto_pop_3 l y) o ->
      red_expr S0 C (spec_call_array_proto_pop_2 l (out_ter S vlen)) o

  | red_spec_call_array_proto_pop_3_empty : forall S0 S C l o, (* 4 *)
      red_expr S C (spec_call_array_proto_pop_3_empty_1 l) o ->
      red_expr S0 C (spec_call_array_proto_pop_3 l (ret S (0 : int))) o

  | red_spec_call_array_proto_pop_3_empty_1 : forall S0 S C l o o1, (* 4a *)
      red_expr S C (spec_object_put l "length" 0 throw_true) o1 ->
      red_expr S C (spec_call_array_proto_pop_3_empty_2 o1) o ->
      red_expr S C (spec_call_array_proto_pop_3_empty_1 l) o

  | red_spec_call_array_proto_pop_3_empty_2 : forall S0 S C r0, (* 4b *)
      red_expr S0 C (spec_call_array_proto_pop_3_empty_2 (out_ter S r0)) (out_ter S undef)

  | red_spec_call_array_proto_pop_3_nonempty : forall S0 S C l (lenuint32 : int) o, (* 5 *)
      lenuint32 > 0 ->
      red_expr S C (spec_call_array_proto_pop_3_nonempty_1 l lenuint32) o ->
      red_expr S0 C (spec_call_array_proto_pop_3 l (ret S lenuint32)) o

  | red_spec_call_array_proto_pop_3_nonempty_1 : forall S0 S C l lenuint32 o o1, (* 5a *)
      red_expr S C (spec_to_string (lenuint32 - 1)) o1 ->
      red_expr S C (spec_call_array_proto_pop_3_nonempty_2 l o1) o ->
      red_expr S C (spec_call_array_proto_pop_3_nonempty_1 l lenuint32) o

  | red_spec_call_array_proto_pop_3_nonempty_2 : forall S0 S C l vindx (velem : value) o o1, (* 5b *)
      red_expr S C (spec_object_get l vindx) o1 ->
      red_expr S C (spec_call_array_proto_pop_3_nonempty_3 l vindx o1) o ->
      red_expr S0 C (spec_call_array_proto_pop_3_nonempty_2 l (out_ter S vindx)) o

  | red_spec_call_array_proto_pop_3_nonempty_3 : forall S0 S C l vindx velem o o1, (* 5c *)
      red_expr S C (spec_object_delete l vindx throw_true) o1 ->
      red_expr S C (spec_call_array_proto_pop_3_nonempty_4 l vindx velem o1) o ->
      red_expr S0 C (spec_call_array_proto_pop_3_nonempty_3 l vindx (out_ter S velem)) o

  | red_spec_call_array_proto_pop_3_nonempty_4 : forall S0 S C l vindx velem o o1 r0, (* 5d *)
      red_expr S C (spec_object_put l "length" vindx throw_true) o1 ->
      red_expr S C (spec_call_array_proto_pop_3_nonempty_5 velem o1) o ->
      red_expr S0 C (spec_call_array_proto_pop_3_nonempty_4 l vindx velem (out_ter S r0)) o

  | red_spec_call_array_proto_pop_3_nonempty_5 : forall S0 S C velem r0, (* 5e *)
      red_expr S0 C (spec_call_array_proto_pop_3_nonempty_5 velem (out_ter S r0)) (out_ter S velem)

  (** Array.prototype.push() (returns value)  (15.4.4.7) *)

  | red_spec_call_array_proto_push : forall S0 S C vthis args o o1, (* 1 *)
      red_expr S C (spec_to_object vthis) o1 ->
      red_expr S C (spec_call_array_proto_push_1 o1 args) o ->
      red_expr S C (spec_call_prealloc prealloc_array_proto_push vthis args) o

  | red_spec_call_array_proto_push_1 : forall S0 S C l args o o1, (* 2 *)
      red_expr S C (spec_object_get l "length") o1 ->
      red_expr S C (spec_call_array_proto_push_2 l args o1) o ->
      red_expr S0 C (spec_call_array_proto_push_1 (out_ter S l) args) o

  | red_spec_call_array_proto_push_2 : forall S0 S C l args vlen y o, (* 3 *)
      red_spec S C (spec_to_uint32 vlen) y ->
      red_expr S C (spec_call_array_proto_push_3 l args y) o ->
      red_expr S0 C (spec_call_array_proto_push_2 l args (out_ter S vlen)) o

    (* don't need 4, because args is a list already *)

  | red_spec_call_array_proto_push_3 : forall S0 S C l args lenuint32 o,
      red_expr S C (spec_call_array_proto_push_4 l args lenuint32) o ->
      red_expr S0 C (spec_call_array_proto_push_3 l args (ret S lenuint32)) o

  | red_spec_call_array_proto_push_4_empty : forall S C l lenuint32 o, (* 5 *)
      red_expr S C (spec_call_array_proto_push_5 l (JsNumber.of_int lenuint32)) o ->
      red_expr S C (spec_call_array_proto_push_4 l nil lenuint32) o

  | red_spec_call_array_proto_push_4_nonempty : forall S C l v vs lenuint32 o, (* 5a *)
      red_expr S C (spec_call_array_proto_push_4_nonempty_1 l vs lenuint32 v) o ->
      red_expr S C (spec_call_array_proto_push_4 l (v::vs) lenuint32) o

  | red_spec_call_array_proto_push_4_nonempty_1 : forall S C l v vs lenuint32 o o1, (* 5b *)
      red_expr S C (spec_to_string (JsNumber.of_int lenuint32)) o1 ->
      red_expr S C (spec_call_array_proto_push_4_nonempty_2 l vs lenuint32 v o1) o ->
      red_expr S C (spec_call_array_proto_push_4_nonempty_1 l vs lenuint32 v) o

  | red_spec_call_array_proto_push_4_nonempty_2 : forall S0 S C l vindx v vs lenuint32 o o1, (* 5b *)
      red_expr S C (spec_object_put l vindx v throw_true) o1 ->
      red_expr S C (spec_call_array_proto_push_4_nonempty_3 l vs lenuint32 v o1) o ->
      red_expr S0 C (spec_call_array_proto_push_4_nonempty_2 l vs lenuint32 v (out_ter S vindx)) o

  | red_spec_call_array_proto_push_4_nonempty_3 : forall S0 S C l v vs lenuint32 o r0, (* 5c *)
      red_expr S C (spec_call_array_proto_push_4 l vs (lenuint32 + 1)) o ->
      red_expr S0 C (spec_call_array_proto_push_4_nonempty_3 l vs lenuint32 v (out_ter S r0)) o

  | red_spec_call_array_proto_push_5 : forall S C l vlen o o1, (* 6 *)
      red_expr S C (spec_object_put l "length" vlen throw_true) o1 ->
      red_expr S C (spec_call_array_proto_push_6 vlen o1) o ->
      red_expr S C (spec_call_array_proto_push_5 l vlen) o

  | red_spec_call_array_proto_push_6 : forall S0 S C vlen r0, (* 7 *)
      red_expr S0 C (spec_call_array_proto_push_6 vlen (out_ter S r0)) (out_ter S vlen)

  (* LATER: special implementation of get_own_property *)

  (*------------------------------------------------------------*)
  (** ** String builtin functions *)

  (** String.prototype.toString() (returns string)  (15.5.4.2) *)

  | red_spec_call_string_proto_to_string : forall S C vthis args o,
      red_expr S C (spec_call_prealloc prealloc_string_proto_value_of vthis args) o ->
      red_expr S C (spec_call_prealloc prealloc_string_proto_to_string vthis args) o

  (** String.prototype.valueOf() (returns string) (15.5.4.3) *)

  | red_spec_call_string_proto_value_of_prim_string : forall S C vthis args,
      type_of vthis = type_string ->
      red_expr S C (spec_call_prealloc prealloc_string_proto_value_of vthis args) (out_ter S vthis)

  | red_spec_call_string_proto_value_of_obj_string : forall S C l v args,
      object_class S l "String" ->
      object_prim_value S l v ->
      red_expr S C (spec_call_prealloc prealloc_string_proto_value_of (value_object l) args) (out_ter S v)

  | red_spec_call_string_proto_value_of_obj_other : forall S C l args o,
      ~ object_class S l "String" ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (spec_call_prealloc prealloc_string_proto_value_of (value_object l) args) o

  | red_spec_call_string_proto_value_of_bad_type : forall S C vthis args o,
      type_of vthis <> type_string ->
      type_of vthis <> type_object ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (spec_call_prealloc prealloc_string_proto_value_of vthis args) o

  (* LATER: special implementation of get_own_property *)

  (*------------------------------------------------------------*)
  (** ** Date builtin functions : LATER *)

  (* LATER: special hint for default_value  *)

  (*------------------------------------------------------------*)
  (** ** Boolean builtin functions *)

  (* LATER: check naming convention *)

  (** Boolean(value)  (returns object_loc)  (15.6.1) *)

  | red_spec_call_bool : forall S C v o vthis args,
      arguments_from args (v::nil) ->
      red_expr S C (spec_to_boolean v) o ->
      red_expr S C (spec_call_prealloc prealloc_bool vthis args) o

  (** new Boolean(value)  (returns object_loc)  (15.6.2.1) *)

  | red_spec_construct_bool : forall S C v o o1 args,
      arguments_from args (v::nil) ->
      red_expr S C (spec_to_boolean v) o1 ->
      red_expr S C (spec_construct_bool_1 o1) o ->
      red_expr S C (spec_construct_prealloc prealloc_bool args) o

   | red_spec_construct_bool_1 : forall O l b S0 S' S C,
      let O1 := object_new prealloc_bool_proto "Boolean" in
      let O := object_with_primitive_value O1 b in
      (l, S') = object_alloc S O ->
      red_expr S0 C (spec_construct_bool_1 (out_ter S b)) (out_ter S' l)

  (*------------------------------------------------------------*)
  (** ** Boolean prototype builtin functions *)

  (** Boolean.prototype.toString() (returns string)  (15.6.4.2)
      Note: behavior encoded using valueOf and conversion to string *)

  | red_spec_call_bool_proto_to_string : forall S C vthis args o1 o,
      (* LATER : check vthis value *)
      red_expr S C (spec_call_prealloc prealloc_bool_proto_value_of vthis args) o1 ->
      red_expr S C (spec_call_bool_proto_to_string_1 o1) o ->
      red_expr S C (spec_call_prealloc prealloc_bool_proto_to_string vthis args) o

  | red_spec_call_bool_proto_to_string_1 : forall S0 S C s b,
      s = (convert_bool_to_string b) ->
      red_expr S0 C (spec_call_bool_proto_to_string_1 (out_ter S b)) (out_ter S s)

  (** Boolean.prototype.valueOf() (returns bool)  (15.6.4.3) *)

  | red_spec_call_bool_proto_value_of : forall S C o vthis args,
      red_expr S C (spec_call_bool_proto_value_of_1 vthis) o ->
      red_expr S C (spec_call_prealloc prealloc_bool_proto_value_of vthis args) o

  | red_spec_call_bool_proto_value_of_1_bool : forall S C v b,
      value_viewable_as "Boolean" S v b ->
      red_expr S C (spec_call_bool_proto_value_of_1 v) (out_ter S b)

   | red_spec_call_bool_proto_value_of_1_not_bool : forall S C v o,
      (forall b, ~ value_viewable_as "Boolean" S v b) ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (spec_call_bool_proto_value_of_1 v) o

  (*------------------------------------------------------------*)
  (** ** Number builtin functions *)

  (** Number(value) (returns object_loc)  (15.7.1.1) *)

  | red_spec_call_number_nil : forall S C vthis,
      red_expr S C (spec_call_prealloc prealloc_number vthis nil) (out_ter S JsNumber.zero)

  | red_spec_call_number_not_nil : forall S C v o vthis args,
      args <> nil ->
      arguments_from args (v::nil) ->
      red_expr S C (spec_to_number v) o ->
      red_expr S C (spec_call_prealloc prealloc_number vthis args) o

  (** new Number([value]) (returns object_loc)  (15.7.2.1) *)

  | red_spec_construct_number_nil : forall S C o,
      red_expr S C (spec_construct_number_1 (out_ter S JsNumber.zero)) o ->
      red_expr S C (spec_construct_prealloc prealloc_number nil) o

  | red_spec_construct_number_not_nil: forall S C v o o1 args,
      args <> nil ->
      arguments_from args (v::nil) ->
      red_expr S C (spec_to_number v) o1 ->
      red_expr S C (spec_construct_number_1 o1) o ->
      red_expr S C (spec_construct_prealloc prealloc_number args) o

  | red_spec_construct_number_1 : forall S0 S C S' O l v,
      let O1 := object_new prealloc_number_proto "Number" in
      let O := object_with_primitive_value O1 v in
      (l, S') = object_alloc S O ->
      red_expr S0 C (spec_construct_number_1 (out_ter S v)) (out_ter S' l)

  (*------------------------------------------------------------*)
  (** ** Number prototype builtin functions *)

  (* Number.prototype.toString() : LATER (see bottom of this file) *)

  (* Number.prototype.valueOf() (returns number)  (15.7.4.4) *)

  | red_spec_call_number_proto_value_of : forall S C o vthis args,
      red_expr S C (spec_call_number_proto_value_of_1 vthis) o ->
      red_expr S C (spec_call_prealloc prealloc_number_proto_value_of vthis args) o

  | red_spec_call_number_proto_value_of_1_number : forall S C v n,
      value_viewable_as "Number" S v n ->
      red_expr S C (spec_call_number_proto_value_of_1 v) (out_ter S n)

   | red_spec_call_number_proto_value_of_1_not_number : forall S C v o,
      (forall n, ~ value_viewable_as "Number" S v n) ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (spec_call_number_proto_value_of_1 v) o

  (*------------------------------------------------------------*)
  (** ** Common functions for throwing errors *)

  (** Throw an error *)

  | red_spec_error : forall S C ne o1 o,
      red_expr S C (spec_build_error (prealloc_native_error_proto ne) undef) o1 ->
      (* LATER: I'm not sure, but shalln't this [prealloc_native_error_proto] be a [prealloc_native_error]? -- Martin *)
      red_expr S C (spec_error_1 o1) o ->
      red_expr S C (spec_error ne) o

  | red_spec_error_1 : forall S0 S C l,
      red_expr S0 C (spec_error_1 (out_ter S l)) (out_ter S (res_throw l))

  (** Throw an error or return a value, depending on a boolean argument *)

  | red_spec_error_or_cst_true : forall S C ne v o,
      red_expr S C (spec_error ne) o ->
      red_expr S C (spec_error_or_cst true ne v) o

  | red_spec_error_or_cst_false : forall S C ne v,
      red_expr S C (spec_error_or_cst false ne v) (out_ter S v)

  (** Throw an error or return void, depending on a boolean argument *)

  | red_spec_error_or_void_true : forall S C ne o,
      red_expr S C (spec_error ne) o ->
      red_expr S C (spec_error_or_void true ne) o

  | red_spec_error_or_void_false : forall S C ne,
      red_expr S C (spec_error_or_void false ne) (out_void S)

  (*------------------------------------------------------------*)
  (** ** Common functions for building errors *)

  (** Build a new error, given a prototype and a message (possibly undefined) *)

  | red_spec_build_error : forall S C O vproto vmsg l S' o,
      O = object_new vproto "Error" ->
      (l, S') = object_alloc S O ->
      red_expr S' C (spec_build_error_1 l vmsg) o ->
      red_expr S C (spec_build_error vproto vmsg) o

  | red_spec_build_error_1_no_msg : forall S C l vmsg,
      vmsg = undef ->
      red_expr S C (spec_build_error_1 l vmsg) (out_ter S l)

  | red_spec_build_error_1_msg : forall S C l vmsg o1 o,
      vmsg <> undef ->
      red_expr S C (spec_to_string vmsg) o1 ->
      red_expr S C (spec_build_error_2 l o1) o ->
      red_expr S C (spec_build_error_1 l vmsg) o

  | red_spec_build_error_2 : forall S0 S S' C l smsg,
      (* TODO: use attrib_nativ on next line, provided it's the right thing to do *)
      object_set_property S l "message" (attributes_data_intro smsg true false true) S' ->
      red_expr S0 C (spec_build_error_2 l (out_ter S smsg)) (out_ter S' l)


  (*------------------------------------------------------------*)
  (** ** Error builtin functions *)

  (** Error(value)  (returns object_loc)  (15.11.1.1) *)

  | red_spec_call_error : forall S C v o vthis args,
      arguments_from args (v::nil) ->
      red_expr S C (spec_build_error prealloc_error_proto v) o ->
      red_expr S C (spec_call_prealloc prealloc_error vthis args) o

  (** new Error(value)  (returns object_loc)  (15.11.2.1) *)

  | red_spec_construct_error : forall S C v o o1 args,
      arguments_from args (v::nil) ->
      red_expr S C (spec_build_error prealloc_error_proto v) o ->
      red_expr S C (spec_construct_prealloc prealloc_error args) o


  (*------------------------------------------------------------*)
  (** ** Error prototype builtin functions *)

  (** Error.prototype.toString()  (15.11.4.4) *)

  | red_spec_call_error_proto_to_string : forall S C args vthis o1 o, (* step 1 *)
      red_expr S C (spec_call_error_proto_to_string_1 vthis) o ->
      red_expr S C (spec_call_prealloc prealloc_error_proto_to_string vthis args) o

  | red_spec_call_error_proto_to_string_1_not_object : forall S C v o, (* step 2 *)
      type_of v <> type_object ->
      red_expr S C (spec_error native_error_type) o ->
      red_expr S C (spec_call_error_proto_to_string_1 v) o

  | red_spec_call_error_proto_to_string_1_object : forall S C l o1 o, (* step 3 *)
      red_expr S C (spec_object_get l "name") o1 ->
      red_expr S C (spec_call_error_proto_to_string_2 l o1) o ->
      red_expr S C (spec_call_error_proto_to_string_1 l) o

  | red_spec_call_error_proto_to_string_2_undef : forall S0 S C l o, (* step 4 if *)
      red_expr S C (spec_call_error_proto_to_string_3 l (out_ter S "Error")) o ->
      red_expr S0 C (spec_call_error_proto_to_string_2 l (out_ter S undef)) o

  | red_spec_call_error_proto_to_string_2_not_undef : forall S0 S C l v o1 o, (* step 4 else *)
      v <> undef ->
      red_expr S C (spec_to_string v) o1 ->
      red_expr S C (spec_call_error_proto_to_string_3 l o1) o ->
      red_expr S0 C (spec_call_error_proto_to_string_2 l (out_ter S v)) o

  | red_spec_call_error_proto_to_string_3 : forall S0 S C l sname o1 o, (* step 5 *)
      red_expr S C (spec_object_get l "message") o1 ->
      red_expr S C (spec_call_error_proto_to_string_4 l sname o1) o ->
      red_expr S0 C (spec_call_error_proto_to_string_3 l (out_ter S sname)) o

  | red_spec_call_error_proto_to_string_4_undef : forall S0 S C l sname o, (* step 6 if *)
      red_expr S C (spec_call_error_proto_to_string_5 l sname (out_ter S "")) o ->
      red_expr S0 C (spec_call_error_proto_to_string_4 l sname (out_ter S undef)) o

  | red_spec_call_error_proto_to_string_4_not_undef : forall S0 S C l sname v o1 o, (* step 6 else *)
      v <> undef ->
      red_expr S C (spec_to_string v) o1 ->
      red_expr S C (spec_call_error_proto_to_string_5 l sname o1) o ->
      red_expr S0 C (spec_call_error_proto_to_string_4 l sname (out_ter S v)) o

  | red_spec_call_error_proto_to_string_5_undef : forall S0 S C l sname o, (* step 7 if *)
      red_expr S C (spec_call_error_proto_to_string_6 l sname (out_ter S "")) o ->
      red_expr S0 C (spec_call_error_proto_to_string_5 l sname (out_ter S undef)) o

  | red_spec_call_error_proto_to_string_5_not_undef : forall S0 S C l sname v o1 o, (* step 7 else *)
      v <> undef ->
      red_expr S C (spec_to_string v) o1 ->
      red_expr S C (spec_call_error_proto_to_string_6 l sname o1) o ->
      red_expr S0 C (spec_call_error_proto_to_string_5 l sname (out_ter S v)) o

  | red_spec_call_error_proto_to_string_6 : forall S0 S C l sname smsg s o, (* steps 8,9,10 *)
      s = (If sname = "" then smsg else If smsg = "" then sname
           else (string_concat (string_concat sname ": ") smsg)) ->
      red_expr S0 C (spec_call_error_proto_to_string_6 l sname (out_ter S smsg)) (out_ter S s)


  (*------------------------------------------------------------*)
  (** ** Native Error builtin functions *)

  (** NativeError(value)  (returns object_loc)  (15.11.1.1) *)

  | red_spec_call_native_error : forall S C v o ne vthis args,
      arguments_from args (v::nil) ->
      red_expr S C (spec_build_error (prealloc_native_error_proto ne) v) o ->
      red_expr S C (spec_call_prealloc (prealloc_native_error ne) vthis args) o

  (** new NativeError(value)  (returns object_loc)  (15.11.2.1) *)

  | red_spec_construct_native_error : forall S C v o o1 ne args,
      arguments_from args (v::nil) ->
      red_expr S C (spec_build_error (prealloc_native_error_proto ne) v) o ->
      red_expr S C (spec_construct_prealloc (prealloc_native_error ne) args) o



(**************************************************************)
(** ** Reduction rules for specification functions *)

with red_spec : forall {T}, state -> execution_ctx -> ext_spec -> specret T -> Prop :=

  (** Abort rule for specification functions *)

  | red_spec_abort : forall S C exts T o,
      out_of_ext_spec exts = Some o ->
      abort o ->
      ~ abort_intercepted_spec exts ->
      red_spec S C exts (@specret_out T o)

  (** Conversion to 32-bit integer (9.5) *)

  | red_spec_to_int32 : forall S C v o1 (y:specret int),
      red_expr S C (spec_to_number v) o1 ->
      red_spec S C (spec_to_int32_1 o1) y ->
      red_spec S C (spec_to_int32 v) y

  | red_spec_to_int32_1 : forall S0 S C n,
      red_spec S0 C (spec_to_int32_1 (out_ter S n)) (ret S (JsNumber.to_int32 n))

  (** Conversion to unsigned 32-bit integer (9.6) *)

  | red_spec_to_uint32 : forall S C v o1 (y:specret int),
      red_expr S C (spec_to_number v) o1 ->
      red_spec S C (spec_to_uint32_1 o1) y ->
      red_spec S C (spec_to_uint32 v) y

  | red_spec_to_uint32_1 : forall S0 S C n,
      red_spec S0 C (spec_to_uint32_1 (out_ter S n)) (ret S (JsNumber.to_uint32 n))

  (** Conversion to unsigned 16-bit integer : LATER (9.7) *)

  (** Auxiliary: conversion of two values at once (9.1) *)

  | red_spec_convert_twice : forall S C ex1 ex2 o1 (y:specret (value*value)),
      red_expr S C ex1 o1 ->
      red_spec S C (spec_convert_twice_1 o1 ex2) y ->
      red_spec S C (spec_convert_twice ex1 ex2) y

  | red_spec_convert_twice_1 : forall S0 S C v1 ex2 o2 (y:specret (value*value)),
      red_expr S C ex2 o2 ->
      red_spec S C (spec_convert_twice_2 v1 o2) y ->
      red_spec S0 C (spec_convert_twice_1 (out_ter S v1) ex2) y

  | red_spec_convert_twice_2 : forall S0 S C v1 v2,
      red_spec S0 C (spec_convert_twice_2 v1 (out_ter S v2)) (ret S (v1,v2))

  (** Auxiliary: [spec_expr_get_value_conv] as a combination
      of [spec_expr_get_value] and a conversion *)

  | red_spec_expr_get_value_conv : forall S C e K (y:specret value) (y1:specret value),
      red_spec S C (spec_expr_get_value e) y1 ->
      red_spec S C (spec_expr_get_value_conv_1 K y1) y ->
      red_spec S C (spec_expr_get_value_conv K e) y

  | red_spec_expr_get_value_conv_1 : forall S0 S C K v o1 (y:specret value),
      red_expr S C (K v) o1 ->
      red_spec S0 C (spec_expr_get_value_conv_2 o1) y ->
      red_spec S0 C (spec_expr_get_value_conv_1 K (ret S v)) y

  | red_spec_expr_get_value_conv_2 : forall S0 S C v,
      red_spec S0 C (spec_expr_get_value_conv_2 (out_ter S v)) (vret S v)

  (** Reduction of lists of expressions *)

  | red_spec_list_expr : forall S C es (y:specret (list value)),
      red_spec S C (spec_list_expr_1 nil es) y ->
      red_spec S C (spec_list_expr es) y

  | red_spec_list_expr_1_nil : forall S C vs,
      red_spec S C (spec_list_expr_1 vs nil) (ret S vs)

  | red_spec_list_expr_1_cons : forall S C vs es e y1 (y:specret (list value)),
      red_spec S C (spec_expr_get_value e) y1 ->
      red_spec S C (spec_list_expr_2 vs y1 es) y ->
      red_spec S C (spec_list_expr_1 vs (e::es)) y

  | red_spec_list_expr_2 : forall S0 S C v vs es (y:specret (list value)),
      red_spec S C (spec_list_expr_1 (vs&v) es) y ->
      red_spec S0 C (spec_list_expr_2 vs (ret S v) es) y

  (** ToPropertyDescriptor ( Obj ) - (returns a Descriptor) (8.10.5) *)

  | red_spec_to_descriptor_not_object : forall S C v (y:specret descriptor), (* Step 1 *)
      type_of v <> type_object ->
      red_spec S C (spec_error_spec native_error_type) y ->
      red_spec S C (spec_to_descriptor v) y

  | red_spec_to_descriptor_object : forall S C l xs x Desc (y:specret descriptor), (* Step 2 *)
      Desc = descriptor_intro_empty ->
      red_spec S C (spec_to_descriptor_1a l Desc) y ->
      red_spec S C (spec_to_descriptor l) y

  | red_spec_to_descriptor_1a : forall S C o1 l Desc (y:specret descriptor), (* step 3 *)
      red_expr S C (spec_object_has_prop l "enumerable") o1 ->
      red_spec S C (spec_to_descriptor_1b o1 l Desc) y ->
      red_spec S C (spec_to_descriptor_1a l Desc) y

  | red_spec_to_descriptor_1b_false : forall S0 S C l Desc (y:specret descriptor), (* step 3, neg *)
      red_spec S C (spec_to_descriptor_2a l Desc) y ->
      red_spec S0 C (spec_to_descriptor_1b (out_ter S false) l Desc) y

  | red_spec_to_descriptor_1b_true : forall S0 S C o1 l Desc (y:specret descriptor), (* step 3a *)
      red_expr S C (spec_object_get l "enumerable")  o1 ->
      red_spec S C (spec_to_descriptor_1c o1 l Desc) y ->
      red_spec S0 C (spec_to_descriptor_1b (out_ter S true) l Desc) y

  | red_spec_to_descriptor_1c : forall S0 S C o1 l v b Desc Desc' (y:specret descriptor), (* step 3b *)
      b = (convert_value_to_boolean v) ->
      Desc' = descriptor_with_enumerable Desc (Some b) ->
      red_spec S C (spec_to_descriptor_2a l Desc') y ->
      red_spec S0 C (spec_to_descriptor_1c (out_ter S v) l Desc) y

  | red_spec_to_descriptor_2a : forall S C o1 l Desc (y:specret descriptor), (* step 4 *)
      red_expr S C (spec_object_has_prop l "configurable") o1 ->
      red_spec S C (spec_to_descriptor_2b o1 l Desc) y ->
      red_spec S C (spec_to_descriptor_2a l Desc) y

  | red_spec_to_descriptor_2b_false : forall S0 S C l Desc (y:specret descriptor), (* step 4, neg *)
      red_spec S C (spec_to_descriptor_3a l Desc) y ->
      red_spec S0 C (spec_to_descriptor_2b (out_ter S false) l Desc) y

  | red_spec_to_descriptor_2b_true : forall S0 S C o1 l Desc (y:specret descriptor), (* step 4a *)
      red_expr S C (spec_object_get l "configurable")  o1 ->
      red_spec S C (spec_to_descriptor_2c o1 l Desc) y ->
      red_spec S0 C (spec_to_descriptor_2b (out_ter S true) l Desc) y

  | red_spec_to_descriptor_2c : forall S0 S C o1 l v b Desc Desc' (y:specret descriptor), (* step 4b *)
      b = (convert_value_to_boolean v) ->
      Desc' = descriptor_with_configurable Desc (Some b) ->
      red_spec S C (spec_to_descriptor_3a l Desc') y ->
      red_spec S0 C (spec_to_descriptor_2c (out_ter S v) l Desc) y

  | red_spec_to_descriptor_3a : forall S C o1 l Desc (y:specret descriptor), (* step 5 *)
      red_expr S C (spec_object_has_prop l "value") o1 ->
      red_spec S C (spec_to_descriptor_3b o1 l Desc) y ->
      red_spec S C (spec_to_descriptor_3a l Desc) y

  | red_spec_to_descriptor_3b_false : forall S0 S C l Desc (y:specret descriptor), (* step 5, neg *)
      red_spec S C (spec_to_descriptor_4a l Desc) y ->
      red_spec S0 C (spec_to_descriptor_3b (out_ter S false) l Desc) y

  | red_spec_to_descriptor_3b_true : forall S0 S C o1 l Desc (y:specret descriptor), (* step 5a *)
      red_expr S C (spec_object_get l "value")  o1 ->
      red_spec S C (spec_to_descriptor_3c o1 l Desc) y ->
      red_spec S0 C (spec_to_descriptor_3b (out_ter S true) l Desc) y

  | red_spec_to_descriptor_3c : forall S0 S C o1 l v Desc Desc' (y:specret descriptor), (* step 5b *)
      Desc' = descriptor_with_value Desc (Some v) ->
      red_spec S C (spec_to_descriptor_4a l Desc') y ->
      red_spec S0 C (spec_to_descriptor_3c (out_ter S v) l Desc) y

  | red_spec_to_descriptor_4a : forall S C o1 l Desc (y:specret descriptor), (* step 6 *)
      red_expr S C (spec_object_has_prop l "writable") o1 ->
      red_spec S C (spec_to_descriptor_4b o1 l Desc) y ->
      red_spec S C (spec_to_descriptor_4a l Desc) y

  | red_spec_to_descriptor_4b_false : forall S0 S C l Desc (y:specret descriptor), (* step 6, neg *)
      red_spec S C (spec_to_descriptor_5a l Desc) y ->
      red_spec S0 C (spec_to_descriptor_4b (out_ter S false) l Desc) y

  | red_spec_to_descriptor_4b_true : forall S0 S C o1 l Desc (y:specret descriptor), (* step 6a *)
      red_expr S C (spec_object_get l "writable")  o1 ->
      red_spec S C (spec_to_descriptor_4c o1 l Desc) y ->
      red_spec S0 C (spec_to_descriptor_4b (out_ter S true) l Desc) y

  | red_spec_to_descriptor_4c : forall S0 S C o1 l v b Desc Desc' (y:specret descriptor), (* step 6b *)
      b = (convert_value_to_boolean v) ->
      Desc' = descriptor_with_writable Desc (Some b) ->
      red_spec S C (spec_to_descriptor_5a l Desc') y ->
      red_spec S0 C (spec_to_descriptor_4c (out_ter S v) l Desc) y

  | red_spec_to_descriptor_5a :forall S C o1 l Desc (y:specret descriptor), (* step 7 *)
      red_expr S C (spec_object_has_prop l "get") o1 ->
      red_spec S C (spec_to_descriptor_5b o1 l Desc) y ->
      red_spec S C (spec_to_descriptor_5a l Desc) y

  | red_spec_to_descriptor_5b_false : forall S0 S C o1 l Desc (y:specret descriptor), (* step 7, neg *)
      red_spec S C (spec_to_descriptor_6a l Desc) y ->
      red_spec S0 C (spec_to_descriptor_5b (out_ter S false) l Desc) y

  | red_spec_to_descriptor_5b_true : forall S0 S C o1 l Desc (y:specret descriptor), (* step 7a *)
      red_expr S C (spec_object_get l "get")  o1 ->
      red_spec S C (spec_to_descriptor_5c o1 l Desc) y ->
      red_spec S0 C (spec_to_descriptor_5b (out_ter S true) l Desc) y

  | red_spec_to_descriptor_5c_error : forall S0 S C l v Desc (y:specret descriptor), (* step 7b *)
      ((is_callable S v = false) /\ (v <> undef)) ->
      red_spec S C (spec_error_spec native_error_type) y ->
      red_spec S0 C (spec_to_descriptor_5c (out_ter S v) l Desc) y

  | red_spec_to_descriptor_5c_ok : forall S0 S C l v Desc Desc' (y:specret descriptor), (* step 7c *)
      ~ ((is_callable S v = false) /\ (v <> undef)) ->
      Desc' = descriptor_with_get Desc (Some v) ->
      red_spec S C (spec_to_descriptor_6a l Desc') y ->
      red_spec S0 C (spec_to_descriptor_5c (out_ter S v) l Desc) y

  | red_spec_to_descriptor_6a :forall S C o1 l Desc (y:specret descriptor), (* step 8 *)
      red_expr S C (spec_object_has_prop l "set") o1 ->
      red_spec S C (spec_to_descriptor_6b o1 l Desc) y ->
      red_spec S C (spec_to_descriptor_6a l Desc) y

  | red_spec_to_descriptor_6b_false : forall S0 S C o1 l Desc (y:specret descriptor), (* step 8, neg *)
      red_spec S C (spec_to_descriptor_7 l Desc) y ->
      red_spec S0 C (spec_to_descriptor_6b (out_ter S false) l Desc) y

  | red_spec_to_descriptor_6b_true : forall S0 S C o1 l Desc (y:specret descriptor), (* step 8a *)
      red_expr S C (spec_object_get l "set")  o1 ->
      red_spec S C (spec_to_descriptor_6c o1 l Desc) y ->
      red_spec S0 C (spec_to_descriptor_6b (out_ter S true) l Desc) y

  | red_spec_to_descriptor_6c_error : forall S0 S C l v Desc (y:specret descriptor), (* step 8b *)
      ((is_callable S v = false) /\ (v <> undef)) ->
      red_spec S C (spec_error_spec native_error_type) y ->
      red_spec S0 C (spec_to_descriptor_6c (out_ter S v) l Desc) y

  | red_spec_to_descriptor_6c_ok : forall S0 S C l v Desc Desc' (y:specret descriptor), (* step 8c *)
      ~ ((is_callable S v = false) /\ (v <> undef)) ->
      Desc' = descriptor_with_set Desc (Some v) ->
      red_spec S C (spec_to_descriptor_7 l Desc') y ->
      red_spec S0 C (spec_to_descriptor_6c (out_ter S v) l Desc) y

  | red_spec_to_descriptor_7_error : forall S C l Desc (y:specret descriptor), (* step 9 *)
      descriptor_inconsistent Desc ->
      red_spec S C (spec_error_spec native_error_type) y ->
      red_spec S C (spec_to_descriptor_7 l Desc) y

  | red_spec_to_descriptor_7_ok : forall S C o l Desc, (* step 10 *)
      ~ descriptor_inconsistent Desc ->
      red_spec S C (spec_to_descriptor_7 l Desc) (ret S Desc)

  (** GetOwnProperty (8.12.1) returns a [full_descriptor] *)

  | red_spec_object_get_own_prop : forall S C l x B (y:specret full_descriptor),
      object_method object_get_own_prop_ S l B ->
      red_spec S C (spec_object_get_own_prop_1 B l x) y ->
      red_spec S C (spec_object_get_own_prop l x) y

  | red_spec_object_get_own_prop_1_default : forall S C l x Ao (y:specret full_descriptor), (* Beginning of steps 1 and 3 *)
      object_property S l x Ao ->
      red_spec S C (spec_object_get_own_prop_2 l x Ao) y ->
      red_spec S C (spec_object_get_own_prop_1 builtin_get_own_prop_default l x) y

  | red_spec_object_get_own_prop_2_none : forall S C l x, (* Step 1 *)
      red_spec S C (spec_object_get_own_prop_2 l x None) (dret S full_descriptor_undef)

  | red_spec_object_get_own_prop_2_some_data : forall S C l x A, (* Step 2 through 8 *)
      red_spec S C (spec_object_get_own_prop_2 l x (Some A)) (ret S (full_descriptor_some A))

  (* Arguments Object: GetOwnProperty (passes a fully-populated property descriptor to the continuation) (10.6) *)

  | red_spec_object_get_own_prop_args_obj : forall S C l x (y:specret full_descriptor) (y1:specret full_descriptor), (* Step 1 *)
      red_spec S C (spec_object_get_own_prop_1 builtin_get_own_prop_default l x) y1 ->
      red_spec S C (spec_args_obj_get_own_prop_1 l x y1) y ->
      red_spec S C (spec_object_get_own_prop_1 builtin_get_own_prop_args_obj l x) y

  | red_spec_object_get_own_prop_args_obj_1_undef : forall S0 S C l x, (* Step 2 *)
      red_spec S0 C (spec_args_obj_get_own_prop_1 l x (ret S full_descriptor_undef)) (ret S full_descriptor_undef)

  | red_spec_object_get_own_prop_args_obj_1_attrs : forall lmap S0 S C l x A (y:specret full_descriptor) (y1:specret full_descriptor), (* Steps 3 - 4 *)
      object_method object_parameter_map_ S l (Some lmap) ->
      red_spec S C (spec_object_get_own_prop lmap x) y1 ->
      red_spec S C (spec_args_obj_get_own_prop_2 l x lmap A y1) y ->
      red_spec S0 C (spec_args_obj_get_own_prop_1 l x (ret S (full_descriptor_some A))) y

  | red_spec_object_get_own_prop_args_obj_2_attrs : forall o1 S0 S C l x lmap A Amap (y:specret full_descriptor), (* Step 5 *)
      red_expr S0 C (spec_object_get lmap x) o1 ->
      red_spec S0 C (spec_args_obj_get_own_prop_3 A o1) y ->
      red_spec S C (spec_args_obj_get_own_prop_2 l x lmap A (ret S0 (full_descriptor_some Amap))) y

  | red_spec_object_get_own_prop_args_obj_3 : forall S C Ad S' v (y:specret full_descriptor), (* Step 5 *)
      red_spec S' C (spec_args_obj_get_own_prop_4 (attributes_data_with_value Ad v)) y ->
      red_spec S C (spec_args_obj_get_own_prop_3 (attributes_data_of Ad) (out_ter S' v)) y
      (* What happens if we have an accessor property descriptor? The spec assumes it is a data property descriptor. *)

  | red_spec_object_get_own_prop_args_obj_2_undef : forall S0 S C l x lmap A (y:specret full_descriptor), (* Step 5 else *)
      red_spec S0 C (spec_args_obj_get_own_prop_4 A) y ->
      red_spec S C (spec_args_obj_get_own_prop_2 l x lmap A (ret S0 full_descriptor_undef)) y

  | red_spec_object_get_own_prop_args_obj_4 : forall S C A, (* Step 6 *)
      red_spec S C (spec_args_obj_get_own_prop_4 A) (ret S (full_descriptor_some A))

  (* String Object: GetOwnProperty (15.5.5.2) returns a [full_descriptor] *)

  | red_spec_object_get_own_prop_string : forall S C l x (y:specret full_descriptor) (y1:specret full_descriptor), (* Step 1 *)
      red_spec S C (spec_object_get_own_prop_1 builtin_get_own_prop_default l x) y1 ->
      red_spec S C (spec_string_get_own_prop_1 l x y1) y ->
      red_spec S C (spec_object_get_own_prop_1 builtin_get_own_prop_string l x) y

  | red_spec_object_get_own_prop_string_1_attrs : forall S0 S C l x A, (* Step 2 *)
      red_spec S0 C (spec_string_get_own_prop_1 l x (ret S (full_descriptor_some A))) (ret S (full_descriptor_some A))

  | red_spec_object_get_own_prop_string_1_undef : forall S0 S C l x (y1:specret int) (y:specret full_descriptor), (* Step 3 *)
      red_spec S C (spec_to_int32 x) y1 ->
      red_spec S C (spec_string_get_own_prop_2 l x y1) y ->
      red_spec S0 C (spec_string_get_own_prop_1 l x (ret S full_descriptor_undef)) y

  | red_spec_object_get_own_prop_string_2 : forall S0 S C l x k o1 (y:specret full_descriptor), (* Step 3 *)
      red_expr S C (spec_to_string (abs k)) o1 ->
      red_spec S C (spec_string_get_own_prop_3 l x o1) y ->
      red_spec S0 C (spec_string_get_own_prop_2 l x (ret S k)) y

  | red_spec_object_get_own_prop_string_3_different : forall S0 S C l x x', (* Step 3 *)
      x <> x' ->
      red_spec S0 C (spec_string_get_own_prop_3 l x (out_ter S x')) (ret S full_descriptor_undef)

  | red_spec_object_get_own_prop_string_3_same : forall S0 S C l s x (y:specret full_descriptor), (* Step 4 *)
      object_prim_value S l s -> (* Can this return something else than a string?  Is that always defined? *)
      red_spec S C (spec_string_get_own_prop_4 x s) y ->
      red_spec S0 C (spec_string_get_own_prop_3 l x (out_ter S x)) y

  | red_spec_object_get_own_prop_string_4 : forall S C l x s y1 (y:specret full_descriptor), (* Step 5 *)
      red_spec S C (spec_to_int32 x) y1 ->
      red_spec S C (spec_string_get_own_prop_5 s y1) y ->
      red_spec S C (spec_string_get_own_prop_4 x s) y

  | red_spec_object_get_own_prop_string_5 : forall S0 S C s idx len (y:specret full_descriptor), (* Step 6 *)
      len = String.length s ->
      red_spec S C (spec_string_get_own_prop_6 s idx len) y ->
      red_spec S0 C (spec_string_get_own_prop_5 s (ret S idx)) y

  | red_spec_object_get_own_prop_string_6_outofbounds : forall S C s idx len, (* Step 7 *)
      len <= idx ->
      red_spec S C (spec_string_get_own_prop_6 s idx len) (ret S full_descriptor_undef)

  | red_spec_object_get_own_prop_string_6_inbounds : forall S C s idx len, (* Step 8, 9 *)
      len > idx ->
      red_spec S C (spec_string_get_own_prop_6 s idx len) (ret S (full_descriptor_some (attributes_data_intro (string_sub s idx 1) false true false)))

  (** Get value on a reference (returns value) (8.7.1) *)

  | red_spec_ref_get_value_value : forall S C v, (* Step 1 *)
      red_spec S C (spec_get_value v) (ret S v)

  | red_spec_ref_get_value_ref_a : forall S C r (y:specret value), (* Steps 2 and 3 *)
      ref_is_unresolvable r ->
      red_spec S C (spec_error_spec native_error_ref) y ->
      red_spec S C (spec_get_value r) y

  | red_spec_ref_get_value_ref_b : forall l S C r o1 (y:specret value), (* Steps 2 and 4 *)
      ref_is_property r ->
      ref_base r = ref_base_type_value l ->
      red_expr S C (spec_object_get l (ref_name r)) o1 ->
      red_spec S C (spec_get_value_ref_b_1 o1) y ->
      red_spec S C (spec_get_value r) y

  | red_spec_ref_get_value_ref_b_prim : forall v S C r o1 (y:specret value), (* Steps 2 and 4 *)
      ref_is_property r ->
      ref_has_primitive_base r ->
      ref_base r = ref_base_type_value v ->
      red_expr S C (spec_prim_value_get v (ref_name r)) o1 ->
      red_spec S C (spec_get_value_ref_b_1 o1) y ->
      red_spec S C (spec_get_value r) y

  | red_spec_ref_get_value_ref_b_1 : forall S0 S C v,  (* LATER: could be made a generic conversion rule *)
      red_spec S0 C (spec_get_value_ref_b_1 (out_ter S v)) (ret S v)

  | red_spec_ref_get_value_ref_c : forall L S C r o1 (y:specret value), (* Step 5. *)
      ref_base r = ref_base_type_env_loc L ->
      red_expr S C (spec_env_record_get_binding_value L (ref_name r) (ref_strict r)) o1 ->
      red_spec S C (spec_get_value_ref_c_1 o1) y ->
      red_spec S C (spec_get_value r) y

  | red_spec_ref_get_value_ref_c_1 : forall S0 S C v, (* LATER: could be made a generic conversion rule *)
      red_spec S0 C (spec_get_value_ref_c_1 (out_ter S v)) (ret S v)

  (** Auxiliary: [spec_expr_get_value] as a combination of [red_expr] and [get_value] *)

  | red_spec_expr_get_value : forall S C e o1 (y:specret value),
      red_expr S C e o1 ->
      red_spec S C (spec_expr_get_value_1 o1) y ->
      red_spec S C (spec_expr_get_value e) y

  | red_spec_expr_get_value_1 : forall S0 S C rv (y:specret value),
      red_spec S C (spec_get_value rv) y ->
      red_spec S0 C (spec_expr_get_value_1 (out_ter S rv)) y

  (*------------------------------------------------------------*)
  (** ** Operations on lexical environments *)

  (** Get identifier reference (10.2.2.1) returns [value] *)

  | red_spec_lexical_env_get_identifier_ref_nil : forall S C x str r,
      r = ref_create_value undef x str ->
      red_spec S C (spec_lexical_env_get_identifier_ref nil x str) (ret S r)

  (* LATER: eliminate this intermediate form that is not useful at all *)
  | red_spec_lexical_env_get_identifier_ref_cons : forall S C L lexs x str (y:specret ref),
      red_spec S C (spec_lexical_env_get_identifier_ref_1 L lexs x str) y ->
      red_spec S C (spec_lexical_env_get_identifier_ref (L::lexs) x str) y

  | red_spec_lexical_env_get_identifier_ref_cons_1 : forall o1 S C L lexs x str (y:specret ref),
      red_expr S C (spec_env_record_has_binding L x) o1 ->
      red_spec S C (spec_lexical_env_get_identifier_ref_2 L lexs x str o1) y ->
      red_spec S C (spec_lexical_env_get_identifier_ref_1 L lexs x str) y

  | red_spec_lexical_env_get_identifier_ref_cons_2_true : forall S0 C L lexs x str S r,
      r = ref_create_env_loc L x str ->
      red_spec S0 C (spec_lexical_env_get_identifier_ref_2 L lexs x str (out_ter S true)) (ret S r)

  | red_spec_lexical_env_get_identifier_ref_cons_2_false : forall S0 C L lexs x str S (y:specret ref),
      red_spec S C (spec_lexical_env_get_identifier_ref lexs x str) y ->
      red_spec S0 C (spec_lexical_env_get_identifier_ref_2 L lexs x str (out_ter S false)) y


  (** Throw an error *) (* LATER:merge *)

  | red_spec_error_spec : forall T S C ne o1 (y:specret T),
      red_expr S C (spec_error ne) o1 ->
      red_spec S C (spec_error_spec_1 o1) y ->
      red_spec S C (spec_error_spec ne) y


  (*------------------------------------------------------------*)

  (** GetProperty (returns a fully-populated property descriptor)  (8.6.2)  *)

  | red_spec_object_get_prop : forall S C l x B (y:specret full_descriptor),
      object_method object_get_prop_ S l B ->
      red_spec S C (spec_object_get_prop_1 B l x) y ->
      red_spec S C (spec_object_get_prop l x) y

  (** GetProperty (8.12.2) returns a [full_descriptor] *)

  | red_spec_object_get_prop_1_default : forall S C l x y1 (y:specret full_descriptor), (* Step 1 *)
      red_spec S C (spec_object_get_own_prop l x) y1 ->
      red_spec S C (spec_object_get_prop_2 l x y1) y ->
      red_spec S C (spec_object_get_prop_1 builtin_get_prop_default l x) y

  | red_spec_object_get_prop_2_not_undef : forall S0 S C l x A, (* Step 2 *)
      red_spec S0 C (spec_object_get_prop_2 l x (ret S (full_descriptor_some A)))
        (ret S (full_descriptor_some A))

  | red_spec_object_get_prop_2_undef : forall S0 S C l x vproto (y:specret full_descriptor), (* Step 3 *)
      object_proto S l vproto ->
      red_spec S C (spec_object_get_prop_3 l x vproto) y ->
      red_spec S0 C (spec_object_get_prop_2 l x (ret S full_descriptor_undef)) y

  | red_spec_object_get_prop_3_null : forall S C l x, (* Step 4 *)
      red_spec S C (spec_object_get_prop_3 l x null) (dret S full_descriptor_undef)

  | red_spec_object_get_prop_3_not_null : forall S C l x lproto (y:specret full_descriptor), (* Step 5 *)
      red_spec S C (spec_object_get_prop lproto x) y ->
      red_spec S C (spec_object_get_prop_3 l x lproto) y

.

