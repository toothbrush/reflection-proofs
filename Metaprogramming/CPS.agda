open import Metaprogramming.Util.Equal
open import Metaprogramming.Util.Apply
open import Reflection
open import Data.Maybe

module Metaprogramming.CPS (U : Set)
           (Uel : U → Set)
           (equal? : (x : U) → (y : U) → Equal? x y)
           (type? : Name → Maybe U)
           (quoteBack : (x : U) → Uel x → Term)
           (ReturnType : U) where

open import Data.Bool hiding (T) renaming (_≟_ to _≟Bool_) 
open import Reflection
open import Data.Nat  hiding (_<_) renaming (_≟_ to _≟-Nat_)
open import Relation.Binary
open import Data.Stream using (Stream ; evens ; odds ; _∷_ )
open import Coinduction
open import Data.Maybe
open import Data.Empty
open import Data.Product hiding (map)
open import Data.Unit hiding (_≤_; _≤?_)
open import Data.Fin hiding (_≺_ ; _+_ ; _<_; _≤_ ; suc ; zero) renaming (compare to fcompare)
open import Data.List

import Metaprogramming.Datatypes
open module DT = Metaprogramming.Datatypes U equal? Uel
import Metaprogramming.TypeCheck
open module TC = Metaprogramming.TypeCheck U equal? type? Uel

{-
   result type, i.e. the type we want cps-transformed terms to
   eventually produce. this also fixes the allowed return type of the
   continuation function, since this must match ReturnType.
   -}
RT : U'
RT = O ReturnType

-- the type of a function after being CPS transformed.
cpsType : U' → U'
cpsType (O x)     = O x
cpsType (t => t₁) = cpsType t => ((cpsType t₁ => RT) => RT)
cpsType (Cont t)  = cpsType t => RT

-- translate the _∈_ objects to an environment where all the types have been transformed.
cpsvar : ∀ {t g} → t ∈ g → (cpsType t) ∈ (map cpsType g)
cpsvar   here    = here
cpsvar (there v) = there (cpsvar v)

-- show that we can add more variables to our environment for free;
-- variables that used to be in the environment are still there, modulo
-- some shifting of indices
weakvar : ∀ {τ Γ} → (τ' : U') → (Γ' : Ctx) → τ ∈ (Γ' ++ Γ) → τ ∈ (Γ' ++ (τ' ∷ Γ))
weakvar t' [] x                 = there x
weakvar t' (x ∷ env) here       = here
weakvar t' (x ∷ env) (there x₁) = there (weakvar t' env x₁)

-- show that we can add a type variable somewhere in the middle of our
-- environment and stuff still is okay.
weak : ∀ {Γ' τ Γ n} → WT (Γ' ++ Γ) τ n → (τ' : U') → WT (Γ' ++ (τ' ∷ Γ)) τ n
weak (Lit x) t                    = Lit x
weak {Γ'} (Var x) t'              = Var (weakvar t' Γ' x)
weak {g'} {t => t1} (Lam .t e) t' = Lam t (weak { t ∷ g' } e t')
weak {g'} {t2} {g} (_⟨_⟩ .{_}{t1}.{t2} e1 e2) t' =
               (weak {g'} {t1 => t2} e1 t')
               ⟨   (weak {g'} {t1} e2 t') ⟩
 
-- increase all the de Bruijn indices by 1. Needs to have some
-- arbitrary type added to the front of the environment to keep
-- the lengths right. special case of weakening, but with empty prefix environment.
shift1 : ∀ {Γ τ n} → (τ' : U') → WT Γ τ n → WT (τ' ∷ Γ) τ n
shift1 t' e = weak {[]} e t'

-- this data type represents the result of a Bove-Capretta termination/accessibility
-- predicate. See the thesis for more information on how this was made.
data TAcc : {Γ : Ctx} {σ : U'} {n : ℕ} → WT Γ σ n → Set where
  TBaseLit : ∀ {Γ σ x} → TAcc (Lit {Γ} {σ} x)
  TBaseVar : ∀ {Γ σ x} → TAcc (Var {Γ} {σ} x)
  TLam : ∀ {Γ t1 t2 n} {a : WT (t1 ∷ Γ) t2 n}
         → TAcc (shift1 (Cont t2) a)
         → TAcc {Γ} {t1 => t2} (Lam {Γ} t1 a)
  TApp : ∀ {Γ σ σ₁ sza szb} {a : WT Γ (σ => σ₁) sza} {b : WT Γ σ szb}
         → TAcc {Γ} {σ => σ₁} a
         → TAcc (shift1 (σ => σ₁) b)
         → TAcc (a ⟨ b ⟩)

-- since the sizes of expressions change rather radically in lambda and application
-- cases after a CPS transform, we have this helper which tells us how big an expression
-- is going to be. This can't be inferred, so it is used in the signature of the T function.

sizeCPS : {σ : U'} {Γ : Ctx} (n : ℕ) → (wt : WT Γ σ n) → (TAcc wt) → (m : ℕ) → ℕ
sizeCPS zero () acc cont
sizeCPS (suc .0) (Var x) acc cont = suc cont + 1
sizeCPS {σ} (suc .(n + m)) (_⟨_⟩ {._} {σ₁} {.σ} {n} {m} f e) (TApp p p₁) cont = sizeCPS n f p (suc (sizeCPS m (shift1 (σ₁ => σ) e) p₁ (suc (suc 3 + cont))))
sizeCPS {t1 => t2} (suc n) (Lam .t1 {.t2}{.n} z) (TLam p) cont = suc (cont + suc (suc (sizeCPS n (shift1 (Cont t2) z) p 1)))
sizeCPS (suc .0) (Lit x₁) acc cont = suc cont + 1

-- T takes an expression and a syntactic continuation, and applies the
--   continuation to a CPS-converted version of the expression. this function
-- normally doesn't pass Agda's termination checker, which is why we provide the TAcc predicate.
-- this does force us to prove ∀ wt → TAcc wt. This is done down below.
T' : {σ : U'} {Γ : Ctx} {n m : ℕ}       → (wt : WT Γ σ n) -- original expression
                                        → (ta : TAcc wt) -- termination predicate
                                        → (cont : WT (map cpsType Γ) (cpsType (Cont σ)) m) -- continuation
                                        → WT (map cpsType Γ) RT (sizeCPS n wt ta m) -- output function with new type & size
T' {O σ}{Γ} .(Lit x) (TBaseLit {.Γ} {.σ} {x})                cont = cont ⟨ Lit x ⟩
T' {σ}{Γ}   .(Var x) (TBaseVar {.Γ} {.σ} {x})                cont = cont ⟨ Var (cpsvar x) ⟩
T' {t1 => t2} {Γ}{suc n}{m} (Lam .t1 expr)     (TLam pf)     cont = cont ⟨ Lam (cpsType t1) (Lam (cpsType (Cont t2)) (T' (shift1 (Cont t2) expr) pf (Var here))) ⟩
T' .{σ₂} {Γ} (_⟨_⟩ .{_}{σ₁}{σ₂}{n}{m} f e)  (TApp pf pf2)    cont =
  T' f pf (Lam (cpsType (σ₁ => σ₂))
                           (T' (shift1 (σ₁ => σ₂) e) pf2 (Lam (cpsType σ₁)
                              (Var (there here) ⟨ Var here ⟩  
                                  ⟨ shift1 (cpsType σ₁) (shift1 (cpsType (σ₁ => σ₂)) cont) ⟩ ))))
                                  
import Metaprogramming.WTWellfounded
open module WTWf = Metaprogramming.WTWellfounded U equal? Uel type? quoteBack ReturnType
open import Induction.WellFounded

{-
  as it turns out, proving ∀ wt → TAcc wt is rather a challenge, since even though the definition
  is rather simple, Agda doesn't believe it terminates (since the recursion isn't simple, because of
  the calls to shift1 before recursing). The other irritation is that Bove and Capretta's technique doesn't
  work here, since the function has (by design) precisely the same recursive call graph as the T' function above,
  leading to an identical proof obligation.

  Therefore, we use the idea of well-foundedness (see thesis for proper explanation) on WT terms, showing
  that in fact, the size of all the recursive arguments is smaller than the inputs.
  -}
module TLemma where

  -- sz extracts the size n from a WT Γ σ n term,
  -- and this relation compares two terms for size.
  -- the WTwrap datatype simply is a dependent pair
  -- of size, environment, type and the WT term with those
  -- values as arguments. Without this encapsulation, we would
  -- have to prove heterogeneous well-foundedness, which is a pain
  -- to say the least. once again, refer to the thesis for a detailed
  -- account of what's going on here.
  _≼_ : Rel WTwrap _
  x ≼ y = sz x < (1 + sz y)

  -- lemma showing that weakening doesn't increase the size of terms.
  shift-pack-size : ∀ {τ Γ Γ' σ n} → (x : WT (Γ' ++ Γ) σ n) → to (weak {Γ'}{σ}{Γ} x τ) ≼ to x
  shift-pack-size (Var x) = <-base
  shift-pack-size (x ⟨ x₁ ⟩) = s<s <-base
  shift-pack-size (Lam σ x) = s<s <-base
  shift-pack-size (Lit x₁) = <-base

-- two trivial lemmas which are necessary because Agda
-- doesn't believe they're trivial.
private
  n<1+n+m : ∀ {n m} → n < suc (n + m)
  n<1+n+m {zero} {zero} = <-base
  n<1+n+m {zero} {suc m} = <-step n<1+n+m
  n<1+n+m {suc n} {m} = s<s n<1+n+m
  
  n<1+m+n : ∀ {n m} → n < suc (m + n)
  n<1+m+n {n} {zero} = <-base
  n<1+m+n {n} {suc m} = <-step (n<1+m+n {n}{m})

open <-on-sz-Well-founded ; open TLemma

{-
  finally we can get around to proving that all WT terms lead to a reasonable
  accessibility predicate TAcc wt; now this function also terminates, which is
  shown by the well-foundedness argument Acc.
  -}
allTsAcc : ∀ {Γ σ n} → (wt : WT Γ σ n) → Acc _≺_ (to wt) → TAcc wt
allTsAcc (Var x) _ = TBaseVar
allTsAcc (Lit x₁) _ = TBaseLit
allTsAcc {Γ} {τ => σ}{suc n} (Lam .τ wt) (acc x) = TLam (allTsAcc (shift1 (Cont σ) wt) (x (to (shift1 (Cont σ) wt)) <-base))
allTsAcc (_⟨_⟩ {Γ}{σ}{σ₁}{n}{m} wt wt₁) (acc x) = TApp (allTsAcc wt (x (to wt) n<1+n+m))
                                                       (allTsAcc (shift1 (σ => σ₁) wt₁) (x (to (shift1 (σ => σ₁) wt₁)) (n<1+m+n {_}{n})) )

-- this is the function we finally export as the CPS API. We get a term wt and cont,
-- and generate the termination/accessibility proof using allTsAcc, passing in the
-- well-foundedness of the packed term, which the standard library kindly provides
-- us in Induction.WellFounded
T : {σ : U'} {Γ : Ctx} {n m : ℕ} → (wt : WT Γ σ n)
                                 → (cont : WT (map cpsType Γ) (cpsType σ => RT) m)
                                 → WT (map cpsType Γ) RT (sizeCPS n wt (allTsAcc wt (wf (to wt))) m)
T wt cont = T' wt (allTsAcc wt (wf (to wt))) cont
