# Validação — CBN Meta 03 Publicador V2

## Resultado

- data: 08/08/2026;
- validação: offline e estrutural;
- workflow: JSON válido, 39 nós;
- testes: **24/24 aprovados**;
- regressão geral do repositório: **44/44 aprovada** após `npm ci` em `scripts/`;
- chamadas externas: nenhuma;
- workflow ativado: não;
- publicação real: nenhuma.

## Cobertura

Foram aprovados os 17 cenários obrigatórios:

1. ambos os canais pendentes;
2. somente Facebook pendente;
3. somente Instagram pendente;
4. Instagram sucesso e Facebook erro;
5. Instagram erro e Facebook sucesso;
6. erro nos dois canais;
7. ambos já publicados;
8. agendamento futuro;
9. pausa geral ativa;
10. configuração crítica ausente;
11. último log `ERRO`;
12. último log `PUBLICADO`;
13. último log `RESERVADO`;
14. Facebook com `message`, sem `caption`;
15. Instagram em `graph.facebook.com`, sem `=={{`;
16. APPEND sem expressão literal quebrada;
17. integridade de todas as conexões.

Também foram aprovadas verificações de `active=false`, gatilhos Manual/Schedule,
timezone, retry HTTP, schema AM:AR, ausência de token materializado, sintaxe de
todos os Code nodes, unicidade dos nomes de nós e descarte case-insensitive de
publish keys literais quebradas do legado.

## Comando

```powershell
node n8n/meta-publicador-v2/validate-meta-publicador-v2.mjs
```

## Riscos e gates restantes

- A importação real pode revelar diferenças de versão do n8n não detectáveis
  pelo validador offline.
- A migração da planilha e as credenciais devem ser conferidas manualmente.
- Um lock/log ambíguo exige revisão humana; não existe replay cego.
- O primeiro teste deve usar somente conteúdo sintético/controlado.
- Ativação, `PAUSA_GERAL=NAO` e publicação real não fazem parte desta entrega.
