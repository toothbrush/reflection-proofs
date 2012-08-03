\documentclass[a4paper]{llncs}

%include polycode.fmt
%if style == newcode
%else
%include agda.fmt
%include codecolour.fmt
%include generated-colour.fmt
%endif

%\usepackage{todonotes}
\usepackage[disable]{todonotes}
\newcommand{\ignore}[1]{}
\def\CC{{C\nolinebreak[4]\hspace{ -.05em}\raisebox{.4ex}{\tiny\bf ++}}}

\ignore{
\begin{code}
module ReflectionProofs where
\end{code}


\begin{code}
-- imports for Evenness
open import Relation.Binary.PropositionalEquality
open import Data.Bool renaming (not to ¬_)
open import Data.Nat
\end{code}
}

\ignore{
\begin{code}
-- imports for Boolean tauto solver
open import Data.String
open import Relation.Nullary hiding (¬_)
open import Data.Product hiding (map)
open import Relation.Binary hiding (_⇒_)
open import Reflection

open import Data.Fin hiding (_+_; pred)
open import Data.Vec renaming (reverse to vreverse ; map to vmap; foldr to vfoldr; _++_ to _v++_)
open import Data.Unit hiding (_≤?_)
open import Data.Empty
open import Data.Sum hiding (map)
open import Data.Product hiding (map)
open import Data.List hiding (_∷ʳ_)
\end{code}
}

\usepackage{amsmath}
\usepackage{semantic}
% things for the semantic package
\reservestyle{\command}{\textbf}
\command{let,in,:,case,of,if,then,else,letrec,nil,cons,false,true,[]}
\mathlig{ -->}{\longrightarrow}


\usepackage{hyperref}
\usepackage{url}

\author{Paul van der Walt \and Wouter Swierstra}
\date{\today}
\title{Applications of Reflection in Agda}
\institute{
\href{mailto:paul@@denknerd.org}{\nolinkurl{paul@@denknerd.org}}, \href{mailto:W.S.Swierstra@@uu.nl}{\nolinkurl{W.S.Swierstra@@uu.nl}}\\
Department of Computer Science, Utrecht University
}

\begin{document}

\maketitle


\begin{abstract}
  This paper explores the recent addition to Agda enabling
  \emph{reflection}, in the style of Lisp, MetaML, and Template
  Haskell. It illustrates several applications of reflection that
  arise in dependently typed programming.
\end{abstract}

\section{Introduction}

The dependently typed programming language
Agda~\cite{norell:thesis,norell2009dependently} has recently been
extended with a \emph{reflection mechanism} for compile time meta
programming in the style of Lisp~\cite{lisp-macros},
MetaML~\cite{metaml}, Template Haskell~\cite{template-haskell}, and
\CC\ templates~\cite{cplusplus}. Agda's reflection mechanisms make it
possible to convert a program fragment into its corresponding abstract
syntax tree and vice versa. In tandem with Agda's dependent types,
this provides promising new programming potential. 

This paper starts exploring the possibilities and limitations of this
new reflection mechanism. It describes several case studies,
exemplative of the kind of problems that can be solved using
reflection. More specifically it makes the following contributions:

\begin{itemize}
\item This paper documents the current status of the reflection
  mechanism. The existing documentation is limited to a paragraph in
  the release notes~\cite{agda-relnotes-228} and comments in the
  compiler's source code. In Section~\ref{sec:reflection} we give
  several short examples of the reflection API in action.
\item This paper illustrates how to use Agda's reflection mechanism to
  automate certain categories of proofs
  (Section~\ref{sec:proof-by-reflection}). The idea of \emph{proof by
    reflection} is certainly not new, but still worth examining in the
  context of this new technology.
\item In the final version of this paper, we will also show how to
  guarantee \emph{type safety of meta-programs}. To illustrate this
  point, we will develop a type safe translation from the simply typed
  lambda calculus to combinatory logic.
\item Finally, the final version will also discuss some of the
  limitations of the current implementation of reflection.
\end{itemize}

The code and examples presented in this paper all compile using the
latest version of Agda 2.3.0.1 and are available on
github.\footnote{\url{http://www.github.com/toothbrush/reflection-proofs}}

\section{Reflection in Agda}
\label{sec:reflection}

Agda's reflection API defines several data types which represent terms,
types, and sorts. These definitions take into account various
features, including hidden arguments and computationally irrelevant
definitions. An overview of the core data types involved has been
included in Figure~\ref{fig:reflection}. In addition to these data
types that represent \emph{terms}, there is some support for
reflecting \emph{definitions} as opposed to terms.

There are several new keywords that can be used to quote and unquote
|Term| values: |quote|, |quoteTerm|, |quoteGoal|, and |unquote|. The
|quote| keyword allows the user to access the internal representation of
any identifier. This internal representation can be used to query the
type or definition of the identifier.
The
examples discussed in this paper will not illustrate |quote|. The other quotation forms,
|quoteTerm| and |quoteGoal|, will be used.

The easiest example of quotation uses the |quoteTerm| keyword to turn
a fragment of concrete syntax into a |Term| data type. Note that the
|quoteTerm| keyword reduces like any other function in Agda. As an
example, the following unit test type checks:
\begin{spec}
example : quoteTerm (\ x -> x) ≡ lam visible (var 0 [])
example = refl
\end{spec}
Furthermore, |quoteTerm| type checks and normalizes its term before
returning the required |Term|, as the following example demonstrates:
\begin{code}
example' : quoteTerm ((\ x -> x) 0) ≡ con (quote Data.Nat.ℕ.zero) []
example' = refl
\end{code}

The |quoteGoal| is slightly different. It is best explained using an
example:

\begin{code}
exampleQuoteGoal : ℕ
exampleQuoteGoal = quoteGoal e in {!!}
\end{code}
The |quoteGoal| keyword binds the variable |e| to the |Term|
representing the type of the current goal. In this example, the value
of $e$ in the hole will be |def ℕ []|, i.e., the |Term| representing
the type |ℕ|.

The |unquote| keyword converts a |Term| data type back to concrete
syntax. Just as |quoteGoal| and |quoteGoal|, it type checks and
normalizes the |Term| before it is spliced into the program text.






\begin{figure}[p]
%if style == poly
  \begin{spec}
      postulate Name : Set

    -- Arguments may be implicit, explicit, or inferred
      data Visibility : Set where
        visible hidden instance : Visibility


    -- Arguments can be relevant or irrelevant.
      data Relevance : Set where
        relevant irrelevant : Relevance

    -- Arguments.
      data Arg A : Set where
        arg : (v : Visibility) (r : Relevance) (x : A) → Arg A
    -- Terms.
      mutual
        data Term : Set where
        -- A bound variable applied to a list of arguments
          var     : (x : ℕ) (args : List (Arg Term)) → Term
        -- Constructor applied to a list of arguments
          con     : (c : Name) (args : List (Arg Term)) → Term
        -- Identifier applied to a list of arguments
          def     : (f : Name) (args : List (Arg Term)) → Term
        -- Lambda abstraction
          lam     : (v : Visibility) (t : Term) → Term
        -- Dependent function types
          pi      : (t₁ : Arg Type) (t₂ : Type) → Term
        -- Sorts
          sort    : Sort → Term
        -- Anything else
          unknown : Term

        data Type : Set where
          el : (s : Sort) (t : Term) → Type

        data Sort : Set where
        -- A Set of a given (possibly neutral) level.
          set     : (t : Term) → Sort
        -- A Set of a given concrete level.
          lit     : (n : ℕ) → Sort
        -- Anything else.
          unknown : Sort
  \end{spec}
%endif
  \caption{The data types for reflecting terms}
  \label{fig:reflection}
\end{figure}



% |Term|s and |Type|s are more interesting: the representation is de Bruijn-style,
% and lambda abstractions are modeled as binding one variable. A variable has a de Bruijn index,
% and may be applied to arguments. Note the |Type| argument in the |lam| constructor:
% this holds the type of the argument expected.

% |con| and |def| are introduced when constructors and definitions, respectively,
% are applied to a (possibly empty) list of arguments. Finally the constructor |unknown| is
% used for things which are not or cannot be represented in this AST (such as function definitions).

% The reflection API also includes a few keywords, such as |quote|,
% |quoteTerm| and |quoteGoal e in ?|.  The |quote| keyword returns the
% |Name| of its argument, which can be useful for comparing to the first
% argument of a |con| constructor, for example, or for looking up more
% information about a given data type. |quoteTerm| returns its argument
% as a |Term|, in other words it gives the AST after parsing,
% type-checking and normalising. For example, |quoteTerm (λ x → x)|
% returns |lam visible (el unknown unknown) (var 0 [])|. Dissecting
% this, we introduced a lambda abstraction, so we expect the |lam|
% constructor. It's one argument is visible, but since we did not
% annotate the term with types, it's type and sort is unknown. Finally,
% the body of the lambda abstraction is just a reference to the
% nearest-bound variable, thus |var 0|, applied to no arguments, hence
% the empty list.


% A common task will be casting the raw |Term| we get into some AST of
% our own, possibly one which enforces some invariants, such as a
% simply-typed lambda calculus representation, ensuring well-typedness.
% A library has been developed which might serve as both an instructive
% example in how to pull apart |Term|s, as well as a helper function,
% since it provides the feature of automatically converting a |Term|
% into some AST type, if a mapping is provided from concrete Agda
% |Name|s to constructors of this AST.


\section{Proof by Reflection}
\label{sec:proof-by-reflection}

The idea behind proof by reflection is simple: given that type theory
is both a programming language and a proof system, it is possible to
define functions that compute proofs. Reflection is an overloaded word
in this context, since in programming language technology reflection
is the capability of converting some piece of concrete program syntax
into a syntax tree object which can be manipulated in the same
system. Here we will present two case studies illustrating proof by
reflection and how Agda's reflection mechanism can make the technique
more usable and accessible.



% These values (in terms of inductive
% types representing the concrete syntax) can then be translated back
% into concrete terms, a process which is called reflection.

% One has to translate the problem into an abstract (equivalent)
% representation, invoke the soundness of the decision function which
% was defined (assuming it returns |true| for the AST instance), giving
% the proof of the given proposition.



\subsection{Simple Example: Evenness}

As a first example, we will cover an example taken from
Chlipala~\cite{chlipala2011certified}, where we develop a procedure to
prove that a number is even automatically. We start by defining the
property |Even| below. There are two constructors: the first
constructor says that zero is even; the second constructor states that
if $n$ is even, then so is $2 + n$.

\begin{code}
data Even      : ℕ → Set where
  isEvenZ      :                          Even 0
  isEvenSS     : {n : ℕ} → Even n     →   Even (2 + n)
\end{code}

Using these rules to produce the proof that some large number |n| is
even can be very tedious: the proof that $2 \times n$ is even requires |n|
applications of the |isEvenSS| constructor. For example, here is the
proof that 6 is even:

\begin{code}
isEven6 : Even 6
isEven6 = isEvenSS (isEvenSS (isEvenSS isEvenZ))
\end{code}

To automate this, we will show how to \emph{compute} the proof
required. We start by defining a predicate |even?| that
returns the unit type when its input is even and bottom otherwise:

\begin{code}
even? : ℕ → Set
even? zero              = ⊤
even? (suc zero)        = ⊥
even? (suc (suc n))     = even? n
\end{code}


Next we need to show that the |even?| function is \emph{sound}. To do
so, we prove that when |even? n| returns |⊤|, the type |Even n| is
inhabited. This is done in the function |soundnessEven|. What is
actually happening here is that we are giving a recipe for
constructing proof trees, such as the one we manually defined for
|isEven6|.

\begin{code}
soundnessEven : {n : ℕ} → even? n → Even n
soundnessEven {0}              tt        = isEvenZ
soundnessEven {1}              ()
soundnessEven {suc (suc n)}    s         = isEvenSS (soundnessEven s)
\end{code}

Note that in the case branch for 1, we do not need to provide a
right-hand side of the function definition. The assumption, |even?
1|, is uninhabited, and we discharge this branch using Agda's
absurd pattern ().

Now that this has been done, if we need a proof that some arbitrary
$n$ is even, we only need to instantiate |soundnessEven|. Note that
the value of $n$ is an implicit argument to |soundnessEven|. The only
argument we need to provide to our |soundnessEven| lemma is a proof
that |even? n| is inhabited. For any closed term, such as the numbers |28|
or |8772|, this proof obligation can be reduced to proving 
|⊤|, which is proven by the single constructor it has, |tt|.

\begin{code}
isEven28        : Even 28
isEven28        = soundnessEven tt

isEven8772      : Even 8772
isEven8772      = soundnessEven tt
\end{code}

Now we can easily get a proof that arbitrarily large numbers are even,
without having to explicitly write down a large proof tree. Note that
it's not possible to write something with type |Even 27|, or any other uneven
number, since the parameter |even? n| cannot be instantiated, thus
|tt| would not be accepted where it is in the |Even 28| example. This will
produce a |⊤ !=< ⊥| type error at compile-time.

Since the type |⊤| is a simple record type, Agda can infer the |tt|
argument, which means we can turn the assumption |even? n| into an
implicit argument, meaning a user could get away with writing just
|soundnessEven| as the proof, letting the inferrer do the rest. For
clarity this is not done here, but the complete implementation
available on github does use this trick.

\subsection{Second Example: Boolean Tautologies}

Another application of the proof by reflection technique
is boolean expressions which are a tautology. We will follow the same
recipe as for even naturals, with one further addition. In the
previous example, the input of our decision procedure |even?| and the
problem domain were both natural numbers. As we shall see, this need
not always be the case.

Take as an example the boolean formula in equation \ref{eqn:tauto-example}.
\begin{align}\label{eqn:tauto-example}
(p_1 \vee q_1) \wedge (p_2 \vee q_2) \Rightarrow (q_1 \vee p_1) \wedge (q_2 \vee p_2)
\end{align}

It is trivial to see that this is a tautology, but proving this 
using deduction rules for booleans would be rather tedious. It
is even worse if we want to check if the formula always holds by
trying all possible variable assignments, since this will give $2^n$
cases, where $n$ is the number of variables.

To automate this process, we will follow a similar approach to
the one given in the previous section. We start by defining an
inductive data type to represent boolean expressions with $n$ free
variables.

\begin{code}
data BoolExpr (n : ℕ) : Set where
  Truth         :                                  BoolExpr n
  Falsehood     :                                  BoolExpr n
  And           : BoolExpr n → BoolExpr n      →   BoolExpr n
  Or            : BoolExpr n → BoolExpr n      →   BoolExpr n
  Not           : BoolExpr n                   →   BoolExpr n
  Imp           : BoolExpr n → BoolExpr n      →   BoolExpr n
  Atomic        : Fin n                        →   BoolExpr n
\end{code}

There is nothing
surprising about this definition; we use the type |Fin n| to ensure
that variables (represented by |Atomic|) are always in scope. If we want to
evaluate the expression, however, we will need some way to map variables to values.
Enter |Env n|, it has fixed size $n$ since a |BoolExpr n| has $n$ free variables.

\begin{code}
Env   : ℕ → Set
Env   = Vec Bool
\end{code}

Now we can define our decision function, which decides if a given
boolean expression is true or not, under some assignment of variables. It does this by evaluating
the formula's AST. For example, |And| is converted to
the boolean function |_∧_|, and its two arguments in turn are
recursively interpreted.
%Here |_∧_|, |_∨_|, |_⇒_| are all defined with
%type |Bool → Bool → Bool|, and |¬_| is of type |Bool → Bool|, making the
%definition of the interpretation function |⟦_⊢_⟧| unsurprising.

\ignore{
\begin{code}
infixr 4 _⇒_
_⇒_ : Bool → Bool → Bool
true  ⇒ true  = true
true  ⇒ false = false
false ⇒ true  = true
false ⇒ false = true
\end{code}
}

\begin{code}
⟦_⊢_⟧ : ∀ {n : ℕ} (e : Env n) → BoolExpr n → Bool
⟦ env     ⊢ Truth       ⟧ = true
⟦ env     ⊢ Falsehood   ⟧ = false
⟦ env     ⊢ And be be₁  ⟧ =     ⟦ env ⊢ be ⟧     ∧      ⟦ env ⊢ be₁ ⟧
⟦ env     ⊢ Or be be₁   ⟧ =     ⟦ env ⊢ be ⟧     ∨      ⟦ env ⊢ be₁ ⟧
⟦ env     ⊢ Not be      ⟧ = ¬   ⟦ env ⊢ be ⟧
⟦ env     ⊢ Imp be be₁  ⟧ =     ⟦ env ⊢ be ⟧     ⇒      ⟦ env ⊢ be₁ ⟧
⟦ env     ⊢ Atomic n    ⟧ = lookup n env
\end{code}

Recall our decision function |even?| in the previous section. It returned
|⊤| if the proposition was valid, |⊥| otherwise. Looking at |⟦_⊢_⟧|, we see that
we should just translate |true| to the unit type and false to the empty type, to get
the analogue of the |even?| function.

We call this function |P|, the string parameter serving to give a clearer type error
to the user, if possible.

\begin{code}
data Error (e : String) : Set where

So   : String → Bool → Set
So   _        true     = ⊤
So   err      false    = Error err

P    : Bool → Set
P    = So "Argument expression does not evaluate to true."
\end{code}
\ignore{
\begin{code}
data Diff : ℕ → ℕ → Set where
  Base : ∀ {n}   → Diff n n
  Step : ∀ {n m} → Diff (suc n) m → Diff n m
\end{code}

\begin{code}
-- peels off all the outermost Pi constructors,
-- returning a term with freeVars free variables.

stripPi : Term → Term
stripPi (pi args (el s t)) = stripPi t
-- identity otherwise
stripPi (var x args) = var  x    args
stripPi (con c args) = con  c    args
stripPi (def f args) = def  f    args
stripPi (lam v σ t)  = lam  v σ  t
stripPi (sort x)     = sort x
stripPi unknown      = unknown

-- TODO get rid of this!
unsafeMinus : (a : ℕ) → (b : ℕ) → ℕ
unsafeMinus zero m = zero
unsafeMinus n₁ zero = n₁
unsafeMinus (suc n₁) (suc m) = unsafeMinus n₁ m


isSoExprQ : (t : Term) → Set
isSoExprQ (var x args) = ⊥
isSoExprQ (con c args) = ⊥
isSoExprQ (def f args) with Data.Nat._≟_ (length args) 2
isSoExprQ (def f args) | yes p with tt
isSoExprQ (def f [])                        | yes () | tt
isSoExprQ (def f (x ∷ []))                  | yes () | tt
isSoExprQ (def f (a ∷ arg v r x ∷ []))      | yes p  | tt with f ≟-Name quote So
isSoExprQ (def f (a ∷ arg v r x ∷ []))      | yes p₁ | tt | yes p = ⊤
isSoExprQ (def f (a ∷ arg v r x ∷ []))      | yes p  | tt | no ¬p = ⊥
isSoExprQ (def f (x ∷ x₃ ∷ x₄ ∷ args))      | yes () | tt
isSoExprQ (def f args)                      | no ¬p with tt
isSoExprQ (def f [])                        | no ¬p | tt = ⊥
isSoExprQ (def f (x ∷ xs))                  | no ¬p | tt = ⊥
isSoExprQ (lam v σ t)                       = ⊥
isSoExprQ (pi t₁ t₂)                        = ⊥
isSoExprQ (sort x)                          = ⊥
isSoExprQ unknown                           = ⊥


stripSo : (t : Term) → isSoExprQ t → Term
stripSo (var x args) ()
stripSo (con c args) ()
stripSo (def f args) pf with Data.Nat._≟_ (length args) 2
stripSo (def f args) pf | yes p with tt
stripSo (def f [])   pf                      | yes () | tt
stripSo (def f (x ∷ [])) pf                  | yes () | tt
stripSo (def f (a ∷ arg v r x ∷ [])) pf      | yes p  | tt with f ≟-Name quote So
stripSo (def f (a ∷ arg v r x ∷ [])) pf  | yes p₁ | tt | yes p = x
stripSo (def f (a ∷ arg v r x ∷ [])) () | yes p | tt | no ¬p
stripSo (def f (x ∷ x₃ ∷ x₄ ∷ args)) pf     | yes () | tt
stripSo (def f args)             pf         | no ¬p with tt
stripSo (def f []) () | no ¬p | tt
stripSo (def f (x ∷ xs)) () | no ¬p | tt
stripSo (lam v σ t)    ()
stripSo (pi t₁ t₂)   ()
stripSo (sort x)     ()
stripSo unknown      ()


isBoolExprQ' : (n : ℕ) → (t : Term) → Set
isBoolExprQ' n (var x args) with suc (unsafeMinus x 0) ≤? n
isBoolExprQ' n (var x args) | yes p = ⊤
isBoolExprQ' n (var x args) | no ¬p = ⊥
isBoolExprQ' n (con tf as) with Data.Nat._≟_ 0 (length as)
isBoolExprQ' n (con tf []) | yes pp with tf ≟-Name quote true
isBoolExprQ' n (con tf []) | yes pp | yes p = ⊤
isBoolExprQ' n (con tf []) | yes pp | no ¬p with tf ≟-Name quote false
isBoolExprQ' n (con tf []) | yes pp | no ¬p  | yes p = ⊤
isBoolExprQ' n (con tf []) | yes pp | no ¬p₁ | no ¬p = ⊥
isBoolExprQ' n (con tf (x ∷ as)) | yes ()
isBoolExprQ' n (con tf []) | no ¬p = ⊥-elim (¬p refl)
isBoolExprQ' n (con tf (a ∷ s)) | no ¬p = ⊥
isBoolExprQ' n (def f []) = ⊥
isBoolExprQ' n (def f (arg v r x ∷ [])) with f ≟-Name quote ¬_
isBoolExprQ' n (def f (arg v r x ∷ [])) | yes p = isBoolExprQ' n x
isBoolExprQ' n (def f (arg v r x ∷ [])) | no ¬p = ⊥
isBoolExprQ' n (def f (arg v r x ∷ arg v₁ r₁ x₁ ∷ [])) with f ≟-Name quote _∧_
isBoolExprQ' n (def f (arg v r x ∷ arg v₁ r₁ x₁ ∷ [])) | yes p = (isBoolExprQ' n x) × (isBoolExprQ' n x₁)
isBoolExprQ' n (def f (arg v r x ∷ arg v₁ r₁ x₁ ∷ [])) | no ¬p with f ≟-Name quote _∨_
isBoolExprQ' n (def f (arg v r x ∷ arg v₁ r₁ x₁ ∷ [])) | no ¬p | yes p = (isBoolExprQ' n x) × (isBoolExprQ' n x₁)
isBoolExprQ' n (def f (arg v r x ∷ arg v₁ r₁ x₁ ∷ [])) | no ¬p₁ | no ¬p with f ≟-Name quote _⇒_
isBoolExprQ' n (def f (arg v r x ∷ arg v₁ r₁ x₁ ∷ [])) | no ¬p₁ | no ¬p | yes p = (isBoolExprQ' n x) × (isBoolExprQ' n x₁)
isBoolExprQ' n (def f (arg v r x ∷ arg v₁ r₁ x₁ ∷ [])) | no ¬p₂ | no ¬p₁ | no ¬p = ⊥
isBoolExprQ' n (def f (x ∷ x₁ ∷ x₂ ∷ args)) = ⊥
isBoolExprQ' n (lam v σ t) = ⊥
isBoolExprQ' n (pi t₁ t₂) = ⊥
isBoolExprQ' n (sort y) = ⊥
isBoolExprQ' n unknown = ⊥

isBoolExprQ : (freeVars : ℕ) → (t : Term) → isSoExprQ t → Set
isBoolExprQ n t pf with stripSo t pf
isBoolExprQ n t pf | t' = isBoolExprQ' n t'

term2boolexpr : (n : ℕ)
        → (t : Term)
        → isBoolExprQ' n t
        → BoolExpr n
term2boolexpr n (var x args) pf with suc (unsafeMinus x 0) ≤? n
term2boolexpr n (var x args) pf | yes p = Atomic (fromℕ≤ {unsafeMinus x 0} p)
term2boolexpr n (var x args) () | no ¬p
term2boolexpr n (con tf []) pf with tf ≟-Name quote true
term2boolexpr n (con tf []) pf | yes p = Truth
term2boolexpr n (con tf []) pf | no ¬p with tf ≟-Name quote false
term2boolexpr n (con tf []) pf | no ¬p  | yes p = Falsehood
term2boolexpr n (con tf []) () | no ¬p₁ | no ¬p
term2boolexpr n (con c (a ∷ rgs)) ()
term2boolexpr n (def f []) ()
term2boolexpr n (def f (arg v r x ∷ [])) pf with f ≟-Name quote ¬_
term2boolexpr n (def f (arg v r x ∷ [])) pf | yes p = Not (term2boolexpr n x pf)
term2boolexpr n (def f (arg v r x ∷ [])) () | no ¬p
term2boolexpr n (def f (arg v r x ∷ arg v₁ r₁ x₁ ∷ [])) pf with f ≟-Name quote _∧_
term2boolexpr n (def f (arg a₁ b₁ x ∷ arg a b x₁ ∷ [])) (proj₁ , proj₂) | yes p = And
  (term2boolexpr n x proj₁)
  (term2boolexpr n x₁ proj₂)
term2boolexpr n (def f (arg a₁ b₁ x ∷ arg a b x₁ ∷ [])) pf | no p with f ≟-Name quote _∨_
term2boolexpr n (def f (arg a₁ b₁ x ∷ arg a b x₁ ∷ [])) (proj₁ , proj₂) | no ¬p | yes p = Or
  (term2boolexpr n x proj₁)
  (term2boolexpr n x₁ proj₂)
term2boolexpr n (def f (arg a₁ b₁ x ∷ arg a b x₁ ∷ [])) pf | no ¬p | no p with f ≟-Name quote _⇒_
term2boolexpr n (def f (arg a₁ b₁ x ∷ arg a b x₁ ∷ [])) (proj₁ , proj₂) | no ¬p₁ | no ¬p | yes p = Imp
  (term2boolexpr n x proj₁)
  (term2boolexpr n x₁ proj₂)
term2boolexpr n (def f (arg a₁ b₁ x ∷ arg a b x₁ ∷ [])) () | no ¬p | no p | no p₁
term2boolexpr n (def f (arg v r x ∷ arg v₁ r₁ x₁ ∷ x₂ ∷ args)) ()
term2boolexpr n (lam v σ t)  ()
term2boolexpr n (pi t₁ t₂) ()
term2boolexpr n (sort x)   ()
term2boolexpr n unknown    ()

zeroId : (n : ℕ) → n ≡ n + 0
zeroId zero                           = refl
zeroId (suc  n) with n + 0 | zeroId n
zeroId (suc .w)    | w     | refl     = refl

succLemma : (n m : ℕ) → suc (n + m) ≡ n + suc m
succLemma zero m    = refl
succLemma (suc n) m = cong suc (succLemma n m)

coerceDiff : {n m k : ℕ} → n ≡ m → Diff k n → Diff k m
coerceDiff refl d = d

zeroleast : (k n : ℕ) → Diff k (k + n)
zeroleast k zero    = coerceDiff (zeroId k) Base
zeroleast k (suc n) = Step (coerceDiff (succLemma k n) (zeroleast (suc k) n))

\end{code}
}

Now that we have these helper functions, it is easy to define what it
means to be a tautology. We quantify over a few boolean variables, and
wrap the formula in our |P| decision function. If the resulting type is
inhabited, the argument to |P| is a tautology, i.e., for each
assignment of the free variables the entire equation still evaluates
to |true|. An example encoding of such a theorem is Figure \ref{fig:exampletheorem}.
\begin{figure}\label{fig:exampletheorem}
\begin{code}
exampletheorem : Set
exampletheorem = (p1 q1 p2 q2 : Bool)   →   P  ((p1 ∨ q1) ∧ (p2 ∨ q2)
                                                   ⇒ (q1 ∨ p1) ∧ (q2 ∨ p2)
                                                   )
\end{code}
\caption{Example encoding of a tautology.}
\end{figure}

Here a complication arises, though. We are quantifying over a list of boolean values \emph{outside}
of the decision function |P|, so proving |P| to be sound will not suffice. We just defined a decision function (|⟦_⊢_⟧|)
to take an environment, an expression, and return a boolean. In Figure \ref{fig:exampletheorem}, though,
we effectively quantified over all possible environments. We are going to need a way
to lift our decision function to arbitrary environments.



The way we do this is the function |foralls|. This function represents the real analogue
of |even?| in this situation: it returns a type which is only inhabited if the argument boolean
expression is true under all variable assignments. This is done by generating a full binary tree
of unit values |⊤|, the single possible value which only exists if the interpretation function |⟦_⊢_⟧|
evaluates to |true| in every leaf. This corresponds precisely to $b$ being a tautology.

The |Diff| argument is unfortunately needed to prove that forallsAcc will eventually produce a
tree with depth equal to the number of free variables in an expression.

\begin{code}
forallsAcc : {n m : ℕ} → BoolExpr m → Env n → Diff n m → Set
forallsAcc b acc    (Base     ) = P ⟦ acc ⊢ b ⟧
forallsAcc b acc    (Step y   ) =
  forallsAcc b (true ∷ acc) y × forallsAcc b (false ∷ acc) y

foralls : {n : ℕ} → BoolExpr n → Set
foralls {n} b = forallsAcc b [] (zeroleast 0 n)
\end{code}

Now we finally know our real decision function, we can set about proving its
soundness. Following the evens example, we want a function something like this.

\begin{spec}
sound : {n : ℕ} → (b : BoolExpr n) → foralls b → ...
\end{spec}
What should the return type of the |sound| lemma be? We would like to
prove that the argument |b| is a tautology, and hence, the |sound|
function should return something of the form |(b1 ... bn : Bool) -> P
B|, where |B| is an expression in the image of the interpretation
|⟦_⊢_⟧|. For instance, the statement |exampletheorem| is a statement
of this form.

The function |proofObligation|, given a |BoolExpr n|, generates the
corresponding proof obligation. That is, it gives back the type which
should be equal to the theorem one wants to prove. It does this by
first introducing $m$ universally quantified boolean
variables. These variables are accumulated in an environment. Finally, when $m$
binders have been introduced, the |BoolExpr| is evaluated under this
environment.


\begin{code}
proofObligation   : (n m : ℕ) → Diff n m → BoolExpr m → Env n → Set
proofObligation   .m   m    (Base    ) b acc = P ⟦ acc ⊢ b ⟧ 
proofObligation   n    m    (Step y  ) b acc =
  (a : Bool) →
      proofObligation (suc n) m y b (a ∷ acc)
\end{code}

\ignore{
\begin{code}
-- dependently typed if-statement
if : {P : Bool → Set} → (b : Bool) → P true → P false → P b
if true  t f = t
if false t f = f

-- very much like ⊥-elim, but for Errors.
Error-elim : ∀ {Whatever : Set} {e : String} → Error e → Whatever
Error-elim ()
\end{code}
}

Now that we can interpret a |BoolExpr n| as a theorem using |proofObligation|, and we have a
way to decide if something is true for a given environment, we still
need to show the soundness of our decision function |foralls|. That is, we need
to be able to show that a formula is true if it holds for every
possible assignment of its variables to |true| or |false|.






\begin{code}
soundnessAcc :   {m : ℕ} →          (b : BoolExpr m) →
                 {n : ℕ} →          (env : Env n) →
                 (d : Diff n m) →   forallsAcc b env d →
                 proofObligation n m d b env
soundnessAcc     bexp     env Base     H with ⟦ env ⊢ bexp ⟧
soundnessAcc     bexp     env Base     H | true  = H
soundnessAcc     bexp     env Base     H | false = Error-elim H
soundnessAcc {m} bexp {n} env (Step y) H =
  λ a → if {λ b → proofObligation (suc n) m y bexp (b ∷ env)} a
    (soundnessAcc bexp (true  ∷ env)    y (proj₁ H))
    (soundnessAcc bexp (false ∷ env)    y (proj₂ H))
\end{code}

\begin{code}
soundness       : {n : ℕ} → (b : BoolExpr n) → foralls b
                → proofObligation 0 n (zeroleast 0 n) b []
soundness {n} b i = soundnessAcc b [] (zeroleast 0 n) i
\end{code}
If we look closely at the definition of |soundnessAcc| (which is
where the work is done -- |soundness| merely calls
|soundnessAcc| with some initial input, namely the |BoolExpr n|, an
empty environment, and the proof
%%%
that the environment is the size of
the number of free variables) -- 
%%%
we see that we build up a function
that, when called with the values assigned to the free variables,
builds up the environment and eventually returns the
leaf from |foralls| which is the proof that the formula is a tautology
in that specific case.

Now, we can prove theorems by calling |soundness b p|, where |b| is the
representation of the formula under consideration, and |p| is the evidence
that all branches of the proof tree are true. Agda is convinced
that the representation does in fact correspond to the concrete
formula, and also that |soundness| gives a valid proof. In fact, we need not
even give |p| explicitly; since the only valid values of |p| are pairs of |tt|,
the argument can be inferred automatically, if it is inhabited.

If the module
passes the type checker, we know our formula is both a tautology, and
that we have the corresponding proof object at our disposal
afterwards, as in the following example.


\begin{code}
rep          : BoolExpr 2
rep          = Imp (And (Atomic (suc zero)) (Atomic zero)) (Atomic zero)

someTauto    : (p q : Bool)         → P( p ∧ q ⇒ q )
someTauto    = soundness rep _
\end{code}

The only part we still have to do manually is to convert the concrete
Agda representation (|p ∧ q ⇒ q|, in this case) into our abstract
syntax (|rep| here). This is unfortunate, as we end up typing out the
formula twice. We also have to count the number of variables
ourselves and convert them the to De Bruijn indices. This is
error-prone given how cluttered the abstract representation can get
for formulae containing many variables. It would be desirable for this
process to be automated. In Sec. \ref{sec:addrefl} a solution is
presented using Agda's recent reflection API.

\subsection{Adding Reflection}\label{sec:addrefl}

We can get rid of the aforementioned duplication using Agda's reflection API. More
specifically, we will use the |quoteGoal| keyword to inspect the
current goal. Given the |Term| representation of the goal, we can
convert it to its corresponding |BoolExpr|.

The conversion between a |Term| and |BoolExpr| is achieved using the
|concrete2abstract| function:
\begin{code}
concrete2abstract    :     (t     : Term)        → (n : ℕ)
                     →     {pf    : isSoExprQ (stripPi t)}
                     →     {pf2   : isBoolExprQ n (stripPi t) pf}
                     →     BoolExpr n
\end{code}
\ignore{
\begin{code}
concrete2abstract t n {pf} {pf2} = term2boolexpr n (stripSo (stripPi t) pf) pf2
\end{code}}\!\!
Note that not every |Term| can be converted to a |BoolExpr|. The
|concrete2abstract| function requires additional assumptions about the
|Term|: it should only contain functions such as |_∧_| or |_∨_|, and
boolean variables. This is ensured by the assumptions
|isBoolExprQ| and friends.

The |concrete2abstract| function is rather verbose, and is mostly omitted.
A representative snippet is given in Fig. \ref{fig:concrete2abstract}. The functions |isBoolExprQ|
and |isSoExprQ| simply traverse the |Term| to see if it fulfills the requirements of
being a boolean expression preceded by a series of universally quantified boolean variables.

\begin{figure}\label{fig:concrete2abstract}
\begin{spec}
term2boolexpr n (con tf []) pf with tf ≟-Name quote true
term2boolexpr n (con tf []) pf | yes p = Truth
...
term2boolexpr n (def f []) ()
term2boolexpr n (def f (arg v r x ∷ [])) pf with f ≟-Name quote ¬_
term2boolexpr n (def f (arg v r x ∷ [])) pf | yes p = Not (term2boolexpr n x pf)
...
\end{spec}
\caption{An illustration of converting a |Term| into a |BoolExpr|.}
\end{figure}


All these pieces are assembled in the |proveTautology| function.
\ignore{

\begin{code}
freeVars : Term → ℕ
freeVars (pi (arg visible relevant (el (lit _) (def Bool []))) (el s t)) = suc (freeVars t)
-- identity otherwise
freeVars (pi a b)     = 0
freeVars (var x args) = 0
freeVars (con c args) = 0
freeVars (def f args) = 0
freeVars (lam v σ t)  = 0
freeVars (sort x)     = 0
freeVars unknown      = 0
\end{code}

}
\begin{code}
proveTautology :    (t     : Term) →
                    {pf    : isSoExprQ (stripPi t)} →
                    let n = freeVars t in
                        {pf2   : isBoolExprQ n (stripPi t) pf} →
                        let b = concrete2abstract t n {pf} {pf2} in
                            foralls b →
                            proofObligation 0 n (zeroleast 0 n) b []
proveTautology t i = 
  soundness (concrete2abstract t (freeVars t)) i
\end{code}
The |proveTautology| function converts a raw |Term| to a |BoolExpr n|
format and calls the |soundness| lemma. It uses a few auxiliary
functions such as |freeVars|, which counts the number of variables
(needed to be able to instantiate the $n$ in |BoolExpr n|), and
|stripSo| \& |stripPi|, which peel off the universal quantifiers and the
function |So| with which we wrap our tautologies. These helper
functions have been ommitted for brevity, since they are rather
cumbersome and add little to the understanding of the subject at
hand.


These are all the ingredients required to automatically prove that
formulae are tautologies.  The following code illustrates the use of
the |proveTautology| functions; we can omit the implicit arguments for
the reasons outlined in the previous section.

\begin{code}
exclMid    : (b : Bool) → P(b ∨ ¬ b)
exclMid    = quoteGoal e in proveTautology e _

peirce     : (p q : Bool) → P(((p ⇒ q) ⇒ p) ⇒ p)
peirce     = quoteGoal e in proveTautology e _

mft        : exampletheorem
mft        = quoteGoal e in proveTautology e _
\end{code}


This shows that the reflection capabilities recently added to Agda are quite useful for
automating certain tedious tasks, since the programmer now need not encode the boolean expression
twice in a slightly different format. The conversion now happens automatically, without loss
of expressive power or general applicability of the proofs resulting from |soundness|.
Furthermore, by using the proof by reflection technique, the proof is generated automatically.




% \section{Type-safe metaprogramming}\label{sec:type-safe-metaprogramming}

% Another area in which an application for the new reflection API was found is that
% of metaprogramming.

% Metaprogramming is a technique which is widely used in the LISP
% community, and involves converting terms in the concrete syntax of a
% programming language into an abstract syntax tree which can be
% inspected and/or manipulated, and possibly (as in the case of LISP) be
% ``reflected'' again, i.e. the (possibly new or modified) AST is made
% concrete again, and thus can be evaluated as if it were code the
% programmer had directly entered into a source file.

% This technique is well-supported and widely used in LISP and more
% recently in Haskell, using the Template Haskell compiler
% extension\cite{sheard2002template}. It has enabled many time-saving
% automations of tasks otherwise requiring
% \emph{boilerplate}\footnote{According to the Oxford English
%   Dictionary, boilerplate is defined as \emph{``standardized pieces of
%     text for use as clauses in contracts or as part of a computer
%     program''}.} code, such as automatically generating
% embedding-projection function pairs for generic programming (for
% example in \cite{norell2004prototyping})
% or % TODO insert example of metaprogramming applications here.
% \dots.

% Clearly, the technique is a very useful one, but it does have one
% limitation (or should we say, possible pitfall), namely that when one
% is developing, for example, a piece of Template Haskell code which
% should generate some function, it often happens that one ends up
% debugging type errors in the produced (machine-generated) code. This
% is a tedious and painful process, since typically generated code is
% much less intuitive and readable than human-written code.

% Here we propose a new way of looking at metaprogramming, namely
% type-safe metaprogramming. It would be great if one could define some
% data structure for, say, lambda calculus, and have the guarantee that
% any term constructed in this AST is type-correct. The obvious
% advantage is then that the compiler will show up errors in whichever
% method tries to build an invalid piece of abstract syntax, as opposed
% to giving an obscure error pointing at some generated code, leaving
% the programmer to figure out how to solve the problem.

% Of course one could achieve a similar framework in, for example,
% Haskell, but having a reflection system in a programming language with
% as powerful a type system as Agda has, is something very new. In this
% section we will explore how one can leverage the power of dependent
% types when metaprogramming.

% \subsection{Example Using $\lambda$-Calculus}

% For the running example in this section, we will look at a
% simply-typed lambda calculus (STLC) defined by the following
% AST. Notice that type-incorrect terms cannot be instantiated, since
% the dependent type signatures of the constructors allow us to express
% constraints such as that a de Bruijn-indexed variable must be at most
% $n$, with $n$ the depth of the current sub-expression, with depth
% defined as the number of $\lambda$'s before one is at top-level
% scope. Another constraint expressed is that an application can only be
% introduced if both sub-expressions have reasonable types. Reasonable
% in this context means that the function being applied must take an
% argument of the type of the to-be-applied sub-expression.

% The type-checker (type unifier, actually) is a nice place to introduce
% general recursion and Bove-Capretta.

% A transformation will be made into SKI combinators.



% \section{Related Work}

% Mention AChlipala and wjzz here.


\section{Discussion}
\label{sec:discussion}

This paper has presented two simple applications of proof by
reflection. In the final version, we will show how
Agda's reflection API has several other applications.


\bibliography{refs}{}
\bibliographystyle{splncs}


% Gebruik geen contractions isn't, didn't etc.
% Beperk je tot de essentie
% Geef voorbeelden

\end{document}
%%% Local Variables:
%%% mode: latex
%%% TeX-master: t
%%% TeX-command-default: "lagda2pdf"
%%% End: 
