# Preferências pessoais

Estas instruções valem para todos os meus projetos, nas duas máquinas
(notebook e computador). Este arquivo é sincronizado — o que eu escrever aqui
aparece na outra máquina na próxima vez que eu abrir o Claude Code.

## Como trabalho

- Responda em português.
- Respostas curtas, objetivas e humanizadas: traduza o termo técnico em
  linguagem clara em vez de despejar jargão. Vale para chamado, incidente,
  análise técnica e para texto que vai para o TL, para o cliente e para o time.
- Em commit, push e merge, **não** inclua assinatura, rodapé ou co-autoria do
  Claude. A mensagem é só o que descreve a mudança.

## Ambiente

- Trabalho em duas máquinas com a mesma configuração, sincronizadas por este
  repositório. Os projetos ficam no mesmo caminho nas duas.
- No Windows, o acesso é pelo WSL: `\\wsl.localhost\Ubuntu\home\hamil`.

## Conexões de banco (quando eu estiver em `\\wsl.localhost\Ubuntu\home\hamil`)

As senhas **não** ficam neste repositório. Elas estão nas minhas preferências
pessoais do Claude (Settings → preferences) e valem nas duas máquinas; se
precisar delas em script, use variável de ambiente ou o cofre da máquina.

**Oracle**

| Item | Valor |
|---|---|
| Network alias | `ORACLE_PRODUCAO` |
| Caminho do `tnsnames` | `C:\instantclient_23_26` |
| Usuário | `U_HAMILTON_NETO` |
| Senha | fora do repositório (ver acima) |

**SQL Server**

| Item | Valor |
|---|---|
| URL | `jdbc:sqlserver://mssqlreportsprd.adm-cesumar.local` |
| Banco | `Lyceum` |
| Autenticação | Windows |
| Senha | fora do repositório (ver acima) |
