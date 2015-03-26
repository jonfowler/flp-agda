module num where

open import Data.Product hiding (zip)
open import Data.Vec as V
open import Data.Maybe as M
open import Data.Fin hiding (_+_ ) hiding (lift)
open import Data.Nat 
open import Function
open import Data.Unit
open import Agda.Primitive
open import Relation.Binary.PropositionalEquality
open import VecI


data Nat (A : Set) : Set where
  Z : Nat A
  S : A → Nat A
  
 
mapNat : {A B : Set} → (A → B) → Nat A → Nat B
mapNat f Z = Z
mapNat f (S x) =  S (f x) 
  
data NatSub : Set where
  hole : NatSub
  Z : NatSub
  S : NatSub → NatSub
  
Subs : ℕ → Set
Subs = Vec NatSub 
  
data Nohole : NatSub → Set where
  Z : Nohole Z
  S : {n : NatSub} → Nohole n → Nohole (S n)
  
Noholes : ∀{M} → Subs M → Set
Noholes σ = VecI Nohole σ
  
Input : Set
Input = Σ NatSub Nohole
  
Inputs : ℕ → Set
Inputs m = Vec Input m
  
data NatVar : Set where
  here : NatVar 
  there : (p : NatVar) → NatVar 
  
data _∈ₛ_ : NatVar → NatSub → Set where
  here : ∀{s} → here ∈ₛ s
  there : ∀{p s} → p ∈ₛ s → there p ∈ₛ S s
  
updZ : (s : NatSub) → NatVar → NatSub
updZ s here = Z 
updZ (S n) (there p) = S (updZ n p)
updZ  _ _ = Z

updS : (s : NatSub) → NatVar → NatSub  × NatVar
updS s here = S hole , there here
updS (S n) (there p) with updS n p
updS (S n) (there p) | s' , p' = S s' , there p'
updS _  _ = Z , here

data _[_]:=_ : (s : NatSub) → NatVar → Maybe (Nat NatVar) → Set where 
  hereZ : Z [ here ]:= just Z 
  hereS : {a : NatSub} → S a [ here ]:= just (S (there here)) 
  hereH : hole [ here ]:= nothing
  thereZ : {s : NatSub}{p : NatVar} → s [ p ]:=  just Z → S s [ there p ]:= just Z 
  thereS : {s : NatSub}{p p' : NatVar} → s [ p ]:=  just (S p' ) → 
                S s [ there p ]:= just (S (there p')) 
  thereH : {s : NatSub}{p : NatVar} → s [ p ]:= nothing → S s [ there p ]:= nothing

 
data ExpM (V : ℕ) (M : ℕ) : Set where
  nat : Nat (ExpM V M) → ExpM V M
  var : Fin V → ExpM V M
  mvar : (x : Fin M) → (p : NatVar )  → ExpM V M 
  case_alt₀_altₛ_ : ExpM V M → ExpM V M → ExpM (suc V) M → ExpM V M
  
Exp : (V : ℕ) → Set
Exp V = ExpM V 0 

  
natToExp : ∀{M V} (s : NatSub) → Nohole s → (p : NatVar) → p ∈ₛ s → ExpM V M
natToExp Z Z here here = nat Z
natToExp (S n) (S n') here here = nat (S (natToExp n n' here here))
natToExp (S n) (S n') (there p) (there p') = natToExp n n' p p'
 
sucVar : {V' : ℕ}(V : ℕ) → Fin (V + V') → Fin (V + suc V')
sucVar zero n = suc n
sucVar (suc V) zero = zero
sucVar (suc V) (suc n) = suc (sucVar V n)

sucExp : {V' M : ℕ}(V : ℕ) → ExpM (V + V') M → ExpM (V + suc V') M
sucExp V (nat Z) = nat Z
sucExp V (nat (S x)) = nat (S (sucExp V x))
sucExp V (var x) = var (sucVar V x) 
sucExp V (mvar x p) = mvar x p
sucExp V (case e alt₀ e₁ altₛ e₂) = case (sucExp V e) alt₀ (sucExp V e₁) altₛ sucExp (suc V) e₂

sub : {V' M : ℕ} (V : ℕ) → ExpM (V + suc V') M → ExpM V' M → ExpM (V + V') M
sub V (nat Z) ef = nat Z
sub V (nat (S x)) ef = nat (S (sub V x ef))
sub zero (var zero) ef = ef
sub zero (var (suc x)) ef = var x
sub (suc V) (var zero) ef = var zero
sub (suc V) (var (suc x)) ef with sub V (var x) ef
... | e' = sucExp 0 e'
sub V (mvar x p) ef = mvar x p
sub V (case e alt₀ e₁ altₛ e₂) ef = case sub V e ef alt₀ sub V e₁ ef altₛ sub (suc V) e₂ ef
  
_[-_-] : {V M : ℕ} → ExpM (suc V) M → ExpM V M → ExpM V M
_[-_-] = sub 0
  
data _↦R_ {M : ℕ} : ExpM 0 M → ExpM 0 M → Set where
  caseZ :  (e : ExpM 0 M) → (e' : ExpM 1 M) → case (nat Z) alt₀ e altₛ e' ↦R e
  caseS : {ef : ExpM 0 M} → (e : ExpM 0 M) → (e' : ExpM 1 M)   
                → case (nat (S ef)) alt₀ e altₛ e' ↦R e' [- ef -]

data Cxt (V : ℕ) (M : ℕ)  : Set where
  hole : Cxt V M
  case_alt₀_altₛ_ : Cxt V M → ExpM V M → ExpM (suc V) M → Cxt V M
  
  
_[/_] : ∀{M V} → Cxt V M → ExpM V M → ExpM V M
hole [/ e ] = e
(case H alt₀ x altₛ x₁) [/ e ] = case H [/ e ] alt₀ x altₛ x₁
  
data _↦_ {M : ℕ} : ExpM 0 M → ExpM 0 M → Set where
  prom : {e e' : ExpM 0 M} → e ↦ e' → (H : Cxt 0 M)  → H [/ e ] ↦ H [/ e' ]

data _↦*_ {M : ℕ} : ExpM 0 M → ExpM 0 M → Set where
  [] : {e : ExpM 0 M} → e ↦* e
  _∷_ : {e e' e'' : ExpM 0 M} → e ↦ e' → e' ↦* e'' → e ↦* e''
  
Env : ℕ → Set
Env m = Subs m × ExpM 0 m

updEnv : ∀{m} → (σ : Subs m) → (x : Fin m) → 
       (p : NatVar) → Env m
updEnv σ x p with lookup x σ
updEnv σ x p | s with updS s p
updEnv σ x p | s | s' , p' = (insert x s' σ) , mvar x p'

data _⇝R_ {m : ℕ} : Env m → Env m → Set where
  lift : {σ : Subs m}{e e' : ExpM 0 m} → e ↦R e' → (σ , e) ⇝R (σ , e')
  var : {σ : Subs m}{x : Fin m}{s : NatSub} → let s = lookup x σ in 
             {p : NatVar}{a : Nat NatVar} → 
             s [ p ]:= just a → 
             (σ , mvar x p) ⇝R (σ , nat (mapNat (mvar x) a))
  bind0 : {σ : Subs m}{x : Fin m}{s : NatSub} → let s = lookup x σ in 
           {p : NatVar} → s [ p ]:= nothing → 
          (σ , mvar x p) ⇝R (insert x (updZ s p) σ , nat Z) 
  bindS : {σ : Subs m}{x : Fin m}{s : NatSub} → let s = lookup x σ in 
    {p : NatVar} → s [ p ]:= nothing → 
    (σ , mvar x p) ⇝R updEnv σ x p

data _≤N_ : NatSub → NatSub → Set where
  ≤hole : {s : NatSub} → hole ≤N s 
  ≤Z : Z ≤N Z 
  ≤S : {s s' : NatSub} → s ≤N s' → S s ≤N S s'
  
----data _≤s_ : {m : ℕ} → Subs m → Subs m → Set where
----  ≤[] : _≤s_ [] []
----  ≤∷ : ∀{m s s'}{σ σ' : Subs m} → s ≤N s' → σ ≤s σ' → 
----                                        (s ∷ σ) ≤s (s' ∷ σ')
--  
_≤s_ : {m : ℕ} → Subs m → Subs m → Set
_≤s_ = VecI₂ _≤N_ 

≤N-refl : ∀{s} → s ≤N s
≤N-refl {hole} = ≤hole
≤N-refl {Z} = ≤Z
≤N-refl {S s} = ≤S ≤N-refl
                                        
≤N-trans : ∀{s s' s''} → s ≤N s' → s' ≤N s'' → s ≤N s''
≤N-trans ≤hole o' = ≤hole
≤N-trans ≤Z o' = o'
≤N-trans (≤S o) (≤S o') = ≤S (≤N-trans o o')

≤s-refl : ∀{m} {σ : Subs m} → σ ≤s σ
≤s-refl {σ = []} = []
≤s-refl {σ = x ∷ σ} = ≤N-refl ∷ ≤s-refl

≤s-trans : ∀{m} {σ σ' σ'' : Subs m} → σ ≤s σ' → σ' ≤s σ'' → σ ≤s σ''
≤s-trans [] [] = []
≤s-trans (s ∷ o) (s' ∷ o') = ≤N-trans s s' ∷ ≤s-trans o o' 

insert-point : ∀{m s}{σ : Subs m}(x : Fin m) → lookup x σ ≤N s  → σ ≤s insert x s σ
insert-point {σ = s ∷ σ} zero a = a ∷ ≤s-refl
insert-point {σ = s ∷ σ} (suc x) a  = ≤N-refl ∷ insert-point x a

updZ-mono : ∀{s}{p : NatVar} → s [ p ]:= nothing → s ≤N updZ s p
updZ-mono hereH = ≤hole
updZ-mono (thereH P) = ≤S (updZ-mono P)

updS-mono : ∀{s}{p : NatVar} → s [ p ]:= nothing → s ≤N proj₁ (updS s p)
updS-mono hereH = ≤hole
updS-mono (thereH P) = ≤S (updS-mono P)
                                        
⇝R-mono : ∀{m}{σ σ' : Subs m}{e e' : ExpM 0 m} →   (σ , e) ⇝R (σ' , e') → σ ≤s σ'
⇝R-mono (lift x) = ≤s-refl
⇝R-mono (var x) = ≤s-refl
⇝R-mono (bind0 {x = x} i) = insert-point x (updZ-mono i)
⇝R-mono (bindS {x = x} i) = insert-point x (updS-mono i)

getOrd : ∀{m}{σ σ' : Subs m} → σ ≤s σ' → (x : Fin m) → lookup x σ ≤N lookup x σ'
getOrd (x ∷ o) zero = x
getOrd (_ ∷ o) (suc x) = getOrd o x

--embExp : ∀{v m}{σ σ' : Subs m} → σ ≤s σ' → ExpM v σ → ExpM v σ'
--embExp o (nat Z) = nat Z
--embExp o (nat (S x)) = nat (S (embExp o x))
--embExp o (var x) = var x
--embExp o (mvar x p) = mvar x (embVar (getOrd o x) p)
--embExp o (case e alt₀ e₁ altₛ e₂) = case embExp o e alt₀ embExp o e₁ altₛ embExp o e₂
--
--embCxt : ∀{m V}{M N : Subs m} → Cxt V M → M ≤s N → ExpM V N → ExpM V N
--embCxt hole o e = e
--embCxt (case H alt₀ e' altₛ e'') o e = case (embCxt H o e) alt₀ (embExp o e') altₛ embExp o e''
--
--repl : ∀{V m}(τ : Subs m) → (VecI Nohole τ) → ExpM V τ →  Exp V
--repl τ is (nat Z) = nat Z
--repl τ is (nat (S e)) = nat (S (repl τ is e))
--repl τ is (var x) = var x
--repl (a ∷ τ) (x ∷ is) (mvar zero p) = natToExp (a , x) p
--repl (a ∷ τ) (x ∷ is) (mvar (suc x₁) p) = repl τ is (mvar x₁ p)
--repl τ is (case e alt₀ e₁ altₛ e₂) = case repl τ is e alt₀ repl τ is e₁ altₛ repl τ is e₂
--
--_⟪_,_,_⟫ : ∀{V m}{σ : Subs m} → ExpM V σ → (τ : Subs m) → (VecI Nohole τ) → σ ≤s τ  → Exp V
--e ⟪ ns , is , o ⟫ = repl  ns is (embExp o e)
----nat Z ⟪ ns , is , o ⟫ = nat Z
----nat (S e) ⟪ ns , is , o ⟫ = nat (S (e ⟪ ns , is , o ⟫))
----var x ⟪ ns , is , o ⟫ = var x
----mvar zero p ⟪ n ∷ ns , i ∷ is , o ∷ _ ⟫ = natToExp (n , i) (embVar o p)
----mvar (suc x) p ⟪ n ∷ ns , i ∷ is , _ ∷ o ⟫ = mvar x p ⟪ ns , is , o ⟫ 
----(case e alt₀ e₁ altₛ e₂) ⟪ ns , is , o ⟫ = case e ⟪ ns , is , o ⟫ alt₀ e₁ ⟪ ns , is , o ⟫ altₛ e₂ ⟪ ns , is , o ⟫
-- 
--
data _⇝_ {m : ℕ} : Env m → Env m → Set where
  prom : {σ σ' : Subs m}{e e' : ExpM 0 m} → 
         (r : (σ , e) ⇝R (σ' , e')) → (H : Cxt 0 m)  → 
           (σ , H [/ e ]) ⇝ (σ' , H [/ e' ])
           
⇝-mono : ∀{m}{σ σ' : Subs m}{e e' : ExpM 0 m} → (σ , e) ⇝ (σ' , e') → σ ≤s σ'
⇝-mono (prom r H) = ⇝R-mono r

data _⇝*_ {m : ℕ} : Env m → Env m → Set where
  [] : {s : Env m} → s ⇝* s
  _∷_ : {s s' s'' : Env m} → (r : s ⇝ s') → (rs : s' ⇝* s'') → s ⇝* s''
  
⇝*-mono : ∀{m}{σ σ' : Subs m}{e e' : ExpM 0 m} → (σ , e) ⇝* (σ' , e') → σ ≤s σ'
⇝*-mono [] = ≤s-refl
⇝*-mono (r ∷ rs) = ≤s-trans (⇝-mono r) (⇝*-mono rs)
  
data _⇝!_ {m : ℕ} : Env m → Env m → Set where
  fill : {σ τ : Subs m}{e : ExpM 0 m}{s : Env m} → VecI Nohole τ → (o : σ ≤s τ) →
       (r : s ⇝* (σ , e)) →  s ⇝! (τ ,  e)
       
inp! : ∀{m}{τ : Subs m} {e : ExpM 0 m}{s : Env m} → s ⇝! (τ , e) → VecI Nohole τ
inp! {s = proj₁ , proj₂} (fill x o x₁) = x

⇝!-mono : ∀{m}{σ τ : Subs m}{e e' : ExpM 0 m} → (σ , e) ⇝! (τ , e') → σ ≤s τ
⇝!-mono (fill x o r) = ≤s-trans (⇝*-mono r) o 

--emb-emp : ∀{V}{e : Exp V} → embExp [] e ≡ e
--emb-emp {e = nat Z} = refl
--emb-emp {e = nat (S e)} = cong (nat ∘ S) emb-emp
--emb-emp {e = var x} = refl
--emb-emp {e = mvar () p}
--emb-emp {e = case e alt₀ e₁ altₛ e₂} = 
--     cong₂ (λ x p → case x alt₀ proj₁ p altₛ proj₂ p) emb-emp (cong₂ _,_ emb-emp emb-emp)
--
--emb-equiv : ∀{m V}{σ τ : Subs m}{τ' : VecI Nohole τ} → (o : σ ≤s τ) → (e : ExpM V σ) →
--                   embExp o e ⟪ τ , τ' , ≤s-refl ⟫ ≡ e ⟪ τ , τ' , o ⟫ 
----emb-equiv {τ' = []} [] e = cong (λ e' → e' ⟪ [] , [] , [] ⟫) (emb-emp {e = e}) 
--emb-equiv o (nat Z) = refl
--emb-equiv o (nat (S e)) = cong (nat ∘ S) (emb-equiv o e)
--emb-equiv o (var x₁) = refl
--emb-equiv (x ∷ o) (mvar zero p) = {!x!}
--emb-equiv (x ∷ o) (mvar (suc x₁) p) = {!!}
--emb-equiv o (case e alt₀ e₁ altₛ e₂) = {!!}
--   
--⇝-sound : ∀{m}{σ τ : Subs m}{e : ExpM 0 σ}{e' : ExpM 0 τ} → 
--                        (r : (σ , e) ⇝! (τ , e')) → 
--            (e ⟪ τ , inp! r , ⇝!-mono r ⟫) ↦* (e' ⟪ τ , inp! r , ≤s-refl ⟫)
--⇝-sound (fill x o []) = {!!} 
--⇝-sound (fill x o (r ∷ rs)) = {!!}
