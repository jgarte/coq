Require Import ssreflect.
Require Import ssrbool TestSuite.ssr_mini_mathcomp.
Global Unset SsrOldRewriteGoalsOrder.

(* under <names>: {occs}[patt]<lemma>.
   under <names>: {occs}[patt]<lemma> by tac1.
   under <names>: {occs}[patt]<lemma> by [tac1 | ...].
 *)

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Axiom daemon : False. Ltac myadmit := case: daemon.

Module Mocks.

(* Mock bigop.v definitions to test the behavior of under with bigops
   without requiring mathcomp *)

Definition eqfun :=
  fun (A B : Type) (f g : forall _ : B, A) => forall x : B, @eq A (f x) (g x).

Section Defix.
Variables (T : Type) (n : nat) (f : forall _ : T, T) (x : T).
Fixpoint loop (m : nat) : T :=
  match m return T with
  | O => x
  | S i => f (loop i)
  end.
Definition iter := loop n.
End Defix.

Parameter eq_bigl :
  forall (R : Type) (idx : R) (op : forall (_ : R) (_ : R), R) (I : Type)
         (r : list I) (P1 P2 : pred I) (F : forall _ : I, R) (_ : @eqfun bool I P1 P2),
    @eq R (@bigop R I idx r (fun i : I => @BigBody R I i op (P1 i) (F i)))
        (@bigop R I idx r (fun i : I => @BigBody R I i op (P2 i) (F i))).

Parameter eq_big :
  forall (R : Type) (idx : R) (op : forall (_ : R) (_ : R), R) (I : Type)
         (r : list I) (P1 P2 : pred I) (F1 F2 : forall _ : I, R) (_ : @eqfun bool I P1 P2)
         (_ : forall (i : I) (_ : is_true (P1 i)), @eq R (F1 i) (F2 i)),
    @eq R (@bigop R I idx r (fun i : I => @BigBody R I i op (P1 i) (F1 i)))
        (@bigop R I idx r (fun i : I => @BigBody R I i op (P2 i) (F2 i))).

Parameter eq_bigr :
  forall (R : Type) (idx : R) (op : forall (_ : R) (_ : R), R) (I : Type)
         (r : list I) (P : pred I) (F1 F2 : forall _ : I, R)
         (_ : forall (i : I) (_ : is_true (P i)), @eq R (F1 i) (F2 i)),
    @eq R (@bigop R I idx r (fun i : I => @BigBody R I i op (P i) (F1 i)))
        (@bigop R I idx r (fun i : I => @BigBody R I i op (P i) (F2 i))).

Parameter big_const_nat :
  forall (R : Type) (idx : R) (op : forall (_ : R) (_ : R), R) (m n : nat) (x : R),
    @eq R (@bigop R nat idx (index_iota m n) (fun i : nat => @BigBody R nat i op true x))
        (@iter R (subn n m) (op x) idx).

Delimit Scope N_scope with num.
Delimit Scope nat_scope with N.

Reserved Notation "\sum_ ( m <= i < n | P ) F"
  (at level 41, F at level 41, i, m, n at level 50,
           format "'[' \sum_ ( m  <=  i  <  n  |  P ) '/  '  F ']'").
Reserved Notation "\sum_ ( m <= i < n ) F"
  (at level 41, F at level 41, i, m, n at level 50,
           format "'[' \sum_ ( m  <=  i  <  n ) '/  '  F ']'").

Local Notation "+%N" := addn (at level 0, only parsing).

Notation "\sum_ ( m <= i < n | P ) F" :=
  (\big[+%N/0%N]_(m <= i < n | P%B) F%N) : (*nat_scope*) big_scope.
Notation "\sum_ ( m <= i < n ) F" :=
  (\big[+%N/0%N]_(m <= i < n) F%N) : (*nat_scope*) big_scope.

Parameter iter_addn_0 : forall m n : nat, @eq nat (@iter nat n (addn m) O) (muln m n).

End Mocks.

Import Mocks.

(*****************************************************************************)

Lemma test_big_nested_1 (F G : nat -> nat) (m n : nat) :
  \sum_(0 <= i < m) \sum_(0 <= j < n | odd (j * 1)) (i + j) =
  \sum_(0 <= i < m) \sum_(0 <= j < n | odd j) (j + i).
Proof.
(* in interactive mode *)
under eq_bigr => i Hi.
  under eq_big => [j|j Hj].
  { rewrite muln1. over. }
  { rewrite addnC. over. }
(* MISSING BETA *)
  over.
by [].
Qed.

Lemma test_big_nested_2 (F G : nat -> nat) (m n : nat) :
  \sum_(0 <= i < m) \sum_(0 <= j < n | odd (j * 1)) (i + j) =
  \sum_(0 <= i < m) \sum_(0 <= j < n | odd j) (j + i).
Proof.
(* in one-liner mode *)
under eq_bigr => i Hi do under eq_big => [j|j Hj] do [rewrite muln1 | rewrite addnC ].
done.
Qed.

Lemma test_big_patt1 (F G : nat -> nat) (n : nat) :
  \sum_(0 <= i < n) (F i + G i) = \sum_(0 <= i < n) (G i + F i) + 0.
Proof.
under [in RHS]eq_bigr => i Hi.
  by rewrite addnC over.
done.
Qed.

Lemma test_big_patt2 (F G : nat -> nat) (n : nat) :
  \sum_(0 <= i < n) (F i + F i) =
  \sum_(0 <= i < n) 0 + \sum_(0 <= i < n) (F i * 2).
Proof.
under [X in _ = _ + X]eq_bigr => i Hi do rewrite mulnS muln1.
by rewrite big_const_nat iter_addn_0.
Qed.

Lemma test_big_occs (F G : nat -> nat) (n : nat) :
  \sum_(0 <= i < n) (i * 0) = \sum_(0 <= i < n) (i * 0) + \sum_(0 <= i < n) (i * 0).
Proof.
under {2}[in RHS]eq_bigr => i Hi do rewrite muln0.
by rewrite big_const_nat iter_addn_0.
Qed.

(* Solely used, one such renaming is useless in practice, but it works anyway *)
Lemma test_big_cosmetic (F G : nat -> nat) (m n : nat) :
  \sum_(0 <= i < m) \sum_(0 <= j < n | odd (j * 1)) (i + j) =
  \sum_(0 <= i < m) \sum_(0 <= j < n | odd j) (j + i).
Proof.
under [RHS]eq_bigr => a A do under eq_bigr => b B do []. (* renaming bound vars *)
myadmit.
Qed.

Lemma test_big_andb (F : nat -> nat) (m n : nat) :
  \sum_(0 <= i < 5 | odd i && (i == 1)) i = 1.
Proof.
under eq_bigl => i do rewrite andb_idl; first by move/eqP->.
under eq_bigr => i do move/eqP=>{1}->. (* the 2nd occ should not be touched *)
myadmit.
Qed.

Lemma test_foo (f1 f2 : nat -> nat) (f_eq : forall n, f1 n = f2 n)
      (G : (nat -> nat) -> nat)
      (Lem : forall f1 f2 : nat -> nat,
          True ->
          (forall n, f1 n = f2 n) ->
          False = False ->
          G f1 = G f2) :
  G f1 = G f2.
Proof.
(*
under x: Lem.
- done.
- rewrite f_eq; over.
- done.
 *)
under Lem => [|x|] do [done|rewrite f_eq|done].
done.
Qed.
