# script-formatacao

Instala todos os meus programas depois de formatar o PC, usando o `winget`.

## Uso

Abra o PowerShell **como Administrador** e rode:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/BrenoRosa9/script-formatacao/main/install.ps1 | iex
```

Pra simular sem instalar nada, baixe o arquivo e rode `.\install.ps1 -DryRun`.

O script Ã© idempotente: o que jÃ¡ estiver instalado Ã© pulado.

## Editando a lista

- Apps do winget ficam em `$apps`. Pra achar o ID de um app: `winget search nome`.
- Apps publicados sÃ³ no GitHub Releases ficam em `$github`.
- O que nÃ£o tem instalador automÃ¡tico fica em `$manual` (o script abre a pÃ¡gina no final).
