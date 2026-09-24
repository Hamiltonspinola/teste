# Memória compartilhada do Claude Code

Faz o Claude Code lembrar do que vocês já fizeram, independente de você estar
no notebook ou no computador. Você fecha o notebook no meio de um trabalho,
senta no computador, e ele continua sabendo o que foi combinado — e a conversa
de ontem está lá para reabrir de onde parou.

## O que é sincronizado

| O quê | Para que serve |
|---|---|
| As anotações do Claude (`memory/`) | Suas preferências, decisões e pendências. É o que evita repetir tudo a cada sessão. |
| O histórico das conversas (`historico/`) | Permite reabrir uma conversa antiga e continuar dali. |
| Suas instruções pessoais (`claude/CLAUDE.md`) | O que vale para todos os projetos, nas duas máquinas. |
| Suas configurações (`claude/settings.json`) | Uma só configuração, igual nos dois lugares. |

Credenciais, login e caches **nunca** entram aqui — estão bloqueados no
`.gitignore`.

## Instalação

O repositório precisa ser **privado**. Faça **uma vez em cada máquina**.

```bash
git clone <url-do-seu-repositorio-privado> ~/claude-brain
~/claude-brain/bootstrap.sh
```

Depois **feche e abra o Claude Code** — é o que faz os ganchos de sincronização
entrarem em vigor.

Para conferir que pegou, abra o Claude Code e rode `/context`: seu `CLAUDE.md`
precisa aparecer na lista de arquivos de memória. E fora dele:

```bash
ls -l ~/.claude/settings.json     # tem que ser um link para ~/claude-brain/
tail ~/claude-brain/.sync.log     # mostra cada sincronização feita
```

O caminho `~/claude-brain` não é opcional: as duas máquinas usam o mesmo, e é
isso que faz a sincronização casar.

Nada é apagado, e o que você já tinha é aproveitado: suas instruções, suas
configurações, sua memória e suas conversas atuais passam a ser as
compartilhadas. Uma cópia do estado anterior fica em
`~/.claude/backup-claude-brain-<data>/` — confira antes de apagar.

Se o `settings.json` desta máquina tiver conteúdo diferente do que já está
sendo compartilhado, o script não escolhe por você: ele guarda o seu com o
sufixo `.seu` no backup e avisa no fim, para você juntar o que quiser manter.

A instalação termina com uma conferência. Se algum passo não tiver funcionado,
o script falha e diz o quê — ele não termina com cara de sucesso sem estar
sincronizando.

## Como usar no dia a dia

Você não faz nada. Ao **abrir** o Claude Code ele busca o que veio da outra
máquina; ao **fechar**, envia o que você fez aqui.

Se quiser sincronizar na hora, sem fechar a sessão:

```bash
~/claude-brain/bin/cc-sync-push.sh --forcar
```

## Três coisas que quebrariam isso (e como estão tratadas)

**Projeto em caminho diferente nas duas máquinas.** O histórico continua
existindo, mas some da lista de conversas para reabrir, porque ele é indexado
pelo caminho da pasta. *Solução: guarde os projetos no mesmo caminho nas duas
máquinas* — por exemplo `~/projetos/<nome>` em ambas. Isso é com você; o
script não tem como adivinhar.

**Conversa antiga apagada sozinha.** O padrão do Claude Code é descartar
conversa com mais de 30 dias. O `bootstrap.sh` sobe esse prazo para o valor de
`RETENCAO_DIAS` no `config.sh` (180 dias de fábrica).

**A mesma conversa aberta nas duas máquinas ao mesmo tempo.** As duas gravam no
mesmo arquivo e uma atropela a outra. Ao abrir o Claude, se a outra máquina
tiver aberto uma sessão nas últimas 8 horas, você recebe um aviso. O aviso não
bloqueia nada — quem decide é você; ele só evita que aconteça por distração.

## Se der conflito

Acontece quando você mexeu nas duas máquinas antes de sincronizar. A memória e
as conversas são juntadas automaticamente (as duas versões são preservadas, sem
travar nada). Só `claude/settings.json` pede decisão sua, e nesse caso os
scripts desfazem a operação pela metade e avisam:

```bash
cd ~/claude-brain && git status
```

Nada é descartado sem você mandar.

## O código não viaja por aqui

Isto é o mais importante deste repositório, e o erro mais caro se passar
despercebido: **o `claude-brain` não leva o seu código.** Ele leva a memória e
as conversas — o relato do que foi feito, por quê, e o que ficou pendente. Ele
não guarda os arquivos alterados e não reconstrói alterações a partir do texto.

São dois caminhos separados:

| O quê | Por onde viaja | Quem faz |
|---|---|---|
| O código alterado | git, no repositório do próprio projeto | você: `commit` e `push` |
| A memória e as conversas | este repositório | automático, ao abrir e fechar |

Se você mexer nos arquivos no notebook e não der `push`, eles não existem
alterados no PC — por mais completa que esteja a memória. Pior: o Claude vai
*saber* que mexeu neles, não vai *ver* a mudança, e pode tentar refazer por
cima.

O ritual é curto:

1. Ao sair de uma máquina: `git commit` e `git push` no projeto, nem que seja um
   commit `wip` numa branch sua
2. Fechar o Claude Code — o resto vai sozinho
3. Ao chegar na outra: `git pull` no projeto
4. Abrir o Claude Code — o resto vem sozinho

Os passos 2 e 4 são automáticos. Os passos 1 e 3 são git normal, e dependem de
você.

### O aviso que te protege disso

`bin/cc-git-estado.sh` olha o repositório do projeto em que a sessão está e
avisa quando algo não bate:

- **Ao abrir**, o estado é entregue ao Claude como contexto, então é ele mesmo
  que te avisa: "este projeto tem 3 commits no servidor que não estão aqui,
  rode `git pull` antes de eu mexer nos arquivos".
- **Ao fechar**, o aviso aparece no terminal: você está saindo com trabalho que
  não saiu desta máquina.

Ele nunca commita nem envia nada por você — empurrar repositório de trabalho
automaticamente é pedir problema. Ele só não deixa você sair no silêncio. Ao
abrir, consulta o servidor com um limite de 10 segundos e sem nunca pedir senha,
então não trava a sessão se a rede ou a VPN estiverem fora.

## Tirar conversas já enviadas

Se você sincronizou com `SINCRONIZAR="tudo"` e depois mudou para `"memoria"`, o
`bootstrap.sh` devolve as conversas para esta máquina e para de enviá-las. Mas
os commits antigos continuam contendo o que já foi enviado — apagar um arquivo
no git não apaga o passado dele.

Para eliminar de verdade, escolha um dos dois.

**Apagar e recriar o repositório** — o mais completo, e o mais simples enquanto
o repositório é novo e só guarda isto. No GitHub, Settings → Danger Zone →
Delete this repository. Crie de novo com o mesmo nome, privado e vazio, e:

```bash
cd ~/claude-brain
rm -rf .git
git init -b main
git add -A
git commit -m "memória compartilhada"
git remote add origin git@github-pessoal:<voce>/claude-brain.git
git push -u origin main
```

Na outra máquina, apague `~/claude-brain` e clone de novo.

**Ou reescrever o histórico**, mantendo o repositório:

```bash
cd ~/claude-brain
git checkout --orphan limpo
git add -A
git commit -m "memória compartilhada"
git branch -D main && git branch -m main
git push -f origin main
```

Na outra máquina, apague `~/claude-brain` e clone de novo — o histórico antigo
não existe mais, e um `git pull` ali daria conflito.

Em ambos os casos, o GitHub ainda pode guardar os objetos soltos por algum tempo
antes de coletá-los. Para um repositório privado seu isso costuma bastar; se o
que vazou for grave a ponto de não bastar, trate como vazamento de segredo:
troque o que for credencial, em vez de apenas apagar o arquivo.

## Configuração

Tudo o que você pode querer mudar está em `config.sh`:

- `SINCRONIZAR` — `"tudo"` (memória + conversas) ou `"memoria"` (só a memória,
  conversas ficam locais em cada máquina)
- `RETENCAO_DIAS` — por quantos dias guardar as conversas
- `AUTO_PUSH` — enviar sozinho ao fechar
- `AVISAR_SESSAO_DUPLA` — o aviso descrito acima

Depois de editar, rode `~/claude-brain/bootstrap.sh` de novo.

## Um cuidado que vale repetir

Com `SINCRONIZAR="tudo"`, o histórico das conversas vai para o repositório. Ele
guarda **tudo que passou pela tela**: conteúdo de arquivo lido, saída de
comando, texto colado. Se em alguma sessão um arquivo de senha foi aberto, ele
está gravado ali dentro.

Use somente repositório privado. Se preferir não correr esse risco, mude para
`SINCRONIZAR="memoria"`: você perde o "reabrir a conversa de ontem", mas mantém
tudo que o Claude aprendeu, que é a parte que mais pesa no dia a dia.

## O que ainda não está aqui

A separação por VPN — cada máquina só mexendo nos projetos da rede que estiver
conectada, controlada a partir do computador. Ficou para uma segunda etapa.
