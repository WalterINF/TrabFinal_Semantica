(* This is an OCaml editor.
   Enter your program here and send it to the toplevel using the "Eval code"
   button or [Ctrl-e]. *)

(*++++++++++++++++++++++++++++++++++++++*)
(*  Interpretador para L1               *)
(*   - inferência de tipos              *)
(*   - avaliador big step com ambiente  *)
(*++++++++++++++++++++++++++++++++++++++*)



(**+++++++++++++++++++++++++++++++++++++++++*)
(*  SINTAXE, AMBIENTE de TIPOS e de VALORES *)
(*++++++++++++++++++++++++++++++++++++++++++*)

  (*  Tipos                 *)
type tipo =
    TyInt
  | TyBool
  | TyFn of tipo * tipo
  | TyPair of tipo * tipo 
  (*  Extensoes ================= *)
  | TyMaybe of tipo
  | TyList of tipo
  | TyNothing of tipo
              

type ident = string

type op = Sum | Sub | Mult | Div | Eq | Gt | Lt | Geq | Leq 

  (*  Sintaxe ======================== *)
type expr =
  | Num of int
  | Var of ident
  | Bool of bool
  | Binop of op * expr * expr
  | Pair of expr * expr
  | Fst of expr
  | Snd of expr
  | If of expr * expr * expr
  | Fn of ident * tipo * expr
  | App of expr * expr
  | Let of ident * tipo * expr * expr
  | LetRec of ident * tipo * expr  * expr 
  (*  Extensoes do sistema de tipos *)
  | Nothing of tipo
  | Just of expr
  | MatchWithNothing of expr * expr * ident * expr 
  (*| Justx of ident * expr //nao sei se ta certo*)
  | Nil of tipo
  | List of expr * expr 
  | MatchWithNil of expr * expr * ident * ident * expr
  | Pipe of expr * expr
                    
  (*  Valores ============ *)
type valor = 
    VNum of int
  | VBool of bool
  | VPair of valor * valor 
  | VClos  of ident * expr * renv
  | VRClos of ident * ident * expr * renv 
  (*  Extensoes da sintaxe de valores *)     
  | VNothing
  | VJust of valor
  | VNil
  | Vlist of valor * valor
and  
  renv = (ident * valor) list
              


  (*  Ambiente ================ *)
type tenv = (ident * tipo) list
    
    

  (*função de substituição*)
let rec update renv x var  =
  (x,var) :: renv

  
(* exceções que não devem ocorrer  *)

exception BugParser
  

  
(**+++++++++++++++++++++++++++++++++++++++++*)
(*         INFERÊNCIA DE TIPOS              *)
(*++++++++++++++++++++++++++++++++++++++++++*)


exception TypeError of string


let rec typeinfer (tenv:tenv) (e:expr) : tipo =
  match e with

    (* TInt  *)
  | Num _ -> TyInt

    (* TVar *)
  | Var x ->
      (match List.assoc_opt x tenv with
         Some t -> t
       | None -> raise (TypeError ("variavel nao declarada:" ^ x)))

    (* TBool *)
  | Bool _ -> TyBool 
  

    (*TOP+  e outras para demais operadores binários *)
  | Binop(oper,e1,e2) ->
      let t1 = typeinfer tenv e1 in
      let t2 = typeinfer tenv e2 in
      if t1 = TyInt && t2 = TyInt then
        (match oper with
           Sum | Sub | Mult |Div -> TyInt
         | Eq | Lt | Gt | Geq | Leq -> TyBool)
      else raise (TypeError "operando nao é do tipo int")

    (* TPair *)
  | Pair(e1,e2) -> TyPair(typeinfer tenv e1, typeinfer tenv e2)
  (* TFst *)
  | Fst e1 ->
      (match typeinfer tenv e1 with
         TyPair(t1,_) -> t1
       | _ -> raise (TypeError "fst espera tipo par"))
    (* TSnd  *)
  | Snd e1 ->
      (match typeinfer tenv e1 with
         TyPair(_,t2) -> t2
       | _ -> raise (TypeError "snd espera tipo par"))

    (* TIf  *)
  | If(e1,e2,e3) ->
      (match typeinfer tenv e1 with
         TyBool ->
           let t2 = typeinfer tenv e2 in
           let t3 = typeinfer tenv e3
           in if t2 = t3 then t2
           else raise (TypeError "then/else com tipos diferentes")
       | _ -> raise (TypeError "condição de IF não é do tipo bool"))

    (* TFn *)
  | Fn(x,t,e1) ->
      let t1 = typeinfer ((x,t) :: tenv) e1
      in TyFn(t,t1)

    (* TApp *)
  | App(e1,e2) ->
      (match typeinfer tenv e1 with
         TyFn(t, t') ->  if (typeinfer tenv e2) = t then t'
           else raise (TypeError "tipo argumento errado" )
       | _ -> raise (TypeError "tipo função era esperado"))

    (* TLet *)
  | Let(x,t,e1,e2) ->
      if (typeinfer tenv e1) = t then typeinfer ((x,t) :: tenv) e2
      else raise (TypeError "expressão nao é do tipo declarado em Let" )

    (* TLetRec *)
  | LetRec(f,(TyFn(t1,t2) as tf), Fn(x,tx,e1), e2) ->
      let tenv_com_tf = (f,tf) :: tenv in
      let tenv_com_tf_tx = (x,tx) :: tenv_com_tf in
      if (typeinfer tenv_com_tf_tx e1) = t2
      then typeinfer tenv_com_tf e2
      else raise (TypeError "tipo da funcao recursiva é diferente do declarado")
  | LetRec _ -> raise BugParser
                  
                  
  (*  Extensoes da inferencia de tipos  ============================== *) 
  

  (*  T-Nothing *) 
  |Nothing(t1) -> TyMaybe(t1)
  
  (*  T-Just *)    
  |Just(e1) -> TyMaybe(typeinfer tenv e1)
        
  (*  T-MatchMB *) 
  |MatchWithNothing(e1,e2,id1,e3) -> 
      let t2 = typeinfer tenv e2 in
      let t3 = typeinfer tenv e3 in
      if t2 = t3 then t2
      else raise (TypeError "tipos do match with diferentes") 
      
          
  (*  T-Nil *) 
  |Nil(t1) -> TyList(t1)
  
  (*  T-Cons *) 
  |List(e1,e2) -> let t1 = typeinfer tenv e1 in
      let t2 = typeinfer tenv e2 in
      (match t2 with 
       |TyList(t3) -> if t1 = t3 then t1 else raise (TypeError "tipos da lista diferentes") 
       |_ -> raise (TypeError "tipos da lista diferentes")) 
  
  
              
  (*  T-MatchLt *)
  |MatchWithNil(e1,e2,id1,id2,e3) ->
      let t2 = typeinfer tenv e2 in
      let t3 = typeinfer tenv e3 in
      if t2 = t3 then t2
      else raise (TypeError "tipos do match with diferentes") 
          
  (*  T-Cons *)
  |Pipe(e1,e2) -> 
      (match typeinfer tenv e2 with
         TyFn(t, t') ->  if (typeinfer tenv e1) = t then t'
           else raise (TypeError "tipo argumento errado" )
       | _ -> raise (TypeError "tipo função era esperado"))
  
  
                  
  
(**+++++++++++++++++++++++++++++++++++++++++*)
(*                 AVALIADOR                *)
(*++++++++++++++++++++++++++++++++++++++++++*)


exception BugTypeInfer

let compute (oper: op) (v1: valor) (v2: valor) : valor =
  match (oper, v1, v2) with
    (Sum, VNum(n1), VNum(n2)) -> VNum (n1 + n2)
  | (Sub, VNum(n1), VNum(n2)) -> VNum (n1 - n2)
  | (Mult, VNum(n1),VNum(n2)) -> VNum (n1 * n2) 
  | (Div, VNum(n1),VNum(n2))  -> VNum (n1 / n2)    
  | (Eq, VNum(n1), VNum(n2))  -> VBool (n1 = n2) 
  | (Gt, VNum(n1), VNum(n2))  -> VBool (n1 > n2)  
  | (Lt, VNum(n1), VNum(n2))  -> VBool (n1 < n2)  
  | (Geq, VNum(n1), VNum(n2)) -> VBool (n1 >= n2) 
  | (Leq, VNum(n1), VNum(n2)) -> VBool (n1 <= n2) 
  | _ -> raise BugTypeInfer


let rec eval (renv:renv) (e:expr) :valor =
  match e with
    Num n -> VNum n
  
  | Var x ->
      (match List.assoc_opt x renv with
         Some v -> v
       | None -> raise BugTypeInfer ) 
      
  | Bool b -> VBool b 
    
  | Binop(oper,e1,e2) ->
      let v1 = eval renv e1 in
      let v2 = eval renv e2 in
      compute oper v1 v2
  
  | Pair(e1,e2) ->
      let v1 = eval renv e1 in
      let v2 = eval renv e2
      in VPair(v1,v2)

  | Fst e ->
      (match eval renv e with
       | VPair(v1,_) -> v1
       | _ -> raise BugTypeInfer)

  | Snd e ->
      (match eval renv e with
       | VPair(_,v2) -> v2
       | _ -> raise BugTypeInfer)


  | If(e1,e2,e3) ->
      (match eval renv e1 with
         VBool true  -> eval renv e2
       | VBool false -> eval renv e3
       | _ -> raise BugTypeInfer )
      
  | Fn(x,_,e1)  -> VClos(x,e1, renv)
                     
  | App(e1,e2) ->
      let v1 = eval renv e1 in
      let v2 = eval renv e2 in
      (match v1 with 
         VClos(   x,e',renv') ->
           eval  (         (x,v2) :: renv')  e' 
       | VRClos(f,x,e',renv') -> 
           eval  ((f,v1) ::(x,v2) :: renv')  e' 
       | _  -> raise BugTypeInfer) 

  | Let(x,_,e1,e2) ->
      let v1 = eval renv e1
      in eval ((x,v1) :: renv) e2

  | LetRec(f,TyFn(t1,t2),Fn(x,tx,e1), e2) when t1 = tx ->
      let renv'=  (f, VRClos(f,x,e1,renv)) :: renv
      in eval renv' e2
  
  | LetRec _ -> raise BugParser 
                  
                  
  (* extensões da semântica de tipos *)

  | Nothing(t1) -> VNothing
    
  | Nil(t1) -> VNil 
    
  | Just(e1) -> VJust(eval renv e1)
                  
  | List(e1,e2) -> Vlist(eval renv e1, eval renv e2)
                  
  | MatchWithNothing (e1, e2, x, e3) -> 
      (match eval renv e1 with
       | VNothing -> eval renv e2
       | VJust v4 -> let renv2 = update renv x v4 in
           eval renv2 e3
       | _ -> raise BugTypeInfer)
  

  | MatchWithNil (e1, e2, x, xs, e3) -> 
      (match eval renv e1 with 
       | VNil -> eval renv e2
       | Vlist(v,vs) -> 
           let renv1 = update renv x v in
           let renv2 = update renv1 xs vs in
           eval renv2 e3
       | _ -> raise BugTypeInfer )
  
  
  | Pipe(e1, e2) -> VNum 404 (*MUDAR*)
      
        
  

  
(* função auxiliar que converte tipo para string *)

let rec ttos (t:tipo) : string =
  match t with
    TyInt  -> "int"
  | TyBool -> "bool"
  | TyFn(t1,t2)   ->  "("  ^ (ttos t1) ^ " --> " ^ (ttos t2) ^ ")"
  | TyPair(t1,t2) ->  "("  ^ (ttos t1) ^ " * "   ^ (ttos t2) ^ ")"
  (*  Extensoes da sintaxe de tipos *) 
  | TyMaybe(t1) -> "Maybe " ^ ttos(t1)
  | TyList(t1) -> ttos(t1) ^ " list"
  | TyNothing(t1) -> "Nothing: " ^ ttos(t1)

(* função auxiliar que converte valor para string *)

let rec vtos (v: valor) : string =
  match v with
    VNum n -> string_of_int n
  | VBool true -> "true"
  | VBool false -> "false"
  | VPair(v1, v2) ->
      "(" ^ vtos v1 ^ "," ^ vtos v1 ^ ")"
  | VClos _ ->  "fn"
  | VRClos _ -> "fn" 
(*  Extensoes da sintaxe de valores *) 
  | VNothing -> "Nothing"
  | VNil -> "Nil"
  | VJust v1 -> "Just" ^ vtos v1 
  | Vlist(v1,v2) -> "(" ^ vtos v1 ^ "," ^ vtos v1 ^ ")"

(* principal do interpretador *)

let int_bse (e:expr) : unit =
  try
    let t = typeinfer [] e in
    let v = eval [] e
    in  print_string ((vtos v) ^ " : " ^ (ttos t))
  with
    TypeError msg ->  print_string ("erro de tipo - " ^ msg) 
  | BugTypeInfer  ->  print_string "corrigir bug em typeinfer"
  | BugParser     ->  print_string "corrigir bug no parser para let rec" 
  
  
   
   (* TESTES =========================================== 
int_bse( Nothing(TyBool) ) -> Nothing: Maybe bool
int_bse( MatchWithNothing(Nothing(TyBool),Num 5, "ddd",Num 6)) -> 5: int
  
  
*)

                        
  
                        