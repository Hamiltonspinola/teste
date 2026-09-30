---
description: Lista e escolhe quais conversas do Claude sincronizam entre as suas máquinas
---

Execute `~/claude-brain/bin/cc-conversas.sh` com os argumentos que o usuário
passou (em `$ARGUMENTS`), ou sem argumento nenhum caso ele não tenha passado.

- sem argumentos: lista os grupos e as conversas, marcando o que sincroniza
- `ignorar <busca>`: para de sincronizar aquela conversa ou grupo
- `incluir <busca>`: volta a sincronizar

`<busca>` pode ser parte do nome de uma conversa — inclusive o título que o
usuário deu pelo app — ou o nome de um grupo.

Mostre a saída do comando ao usuário. Se ela indicar que a busca casou com mais
de uma conversa, apresente as opções e pergunte qual ele quer, em vez de
escolher por conta própria.

Nada é apagado por este comando: ignorar só impede que a conversa viaje para a
outra máquina. Se o usuário pedir para apagar de verdade algo que já foi
enviado, aponte a seção "Tirar conversas já enviadas" do
`~/claude-brain/README.md`.
