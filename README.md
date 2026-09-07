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

Faça **uma vez em cada máquina**. O repositório precisa ser **privado**.

```bash
git clone <url-do-seu-repositorio-privado> ~/claude-brain
~/claude-brain/bootstrap.sh
```

O caminho `~/claude-brain` não é opcional: as duas máquinas usam o mesmo, e é
isso que faz a sincronização casar.

Nada é apagado. O que já existia na sua configuração é movido para
`~/.claude/backup-claude-brain-<data>/`. Confira que está tudo certo antes de
apagar essa pasta.

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
