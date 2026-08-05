# Playbook Editorial — Instagram e Facebook da CBN Crédito

**Versão:** 1.0  
**Data:** 04/08/2026  
**Escopo:** BKL-078 — automação e operação editorial dos canais oficiais.

## Cadência atual

- Três publicações por dia.
- Horários: **09h, 13h e 18h**.
- Publicação manual pela Meta enquanto a automação oficial no n8n não estiver validada.
- Nenhum conteúdo é publicado sem aprovação humana.

## Formato padrão

- Feed: proporção **4:5**.
- Tamanho preferencial: **1080 × 1350 px**.
- Todas as páginas do mesmo carrossel devem possuir exatamente a mesma dimensão.
- Post estático é criado diretamente no tamanho final.
- Reels permanecem pausados até existir matéria-prima ou ferramenta de vídeo adequada.

## Regra obrigatória para carrosséis

1. Idealizar o post.
2. Planejar o storytelling ou a estrutura educativa.
3. Validar as informações importantes.
4. Criar um prompt individual para cada página.
5. Gerar cada imagem separadamente.
6. Nunca gerar mosaico para recortar depois.
7. Conferir dimensão, ortografia, logo e coerência antes de programar.
8. Logo completa na capa e no encerramento.
9. Páginas internas usam `@cbncredito` e contador discreto.

## Pilares

### 09h — Produto ou dúvida frequente

Apresentar um produto ou responder uma dúvida com abordagem responsável e educativa.

### 13h — Educação ou storytelling

Gerar salvamentos, compartilhamentos e retenção, com explicações ou narrativas ilustrativas.

### 18h — Institucional ou conversão

Fortalecer confiança, explicar a forma de atendimento e levar para o WhatsApp.

A programação pode variar conforme a pauta, mas a grade deve manter equilíbrio entre produto, educação e confiança.

## Estrutura visual

- Alternar fundo azul-marinho, fundo claro e fotografia.
- Usar ícones lineares, cartões arredondados e detalhes turquesa.
- Manter títulos fortes e legíveis.
- Usar poucas informações por bloco.
- Evitar repetição excessiva do mesmo layout.
- Usar a logo oficial sem redesenho.

## CTA padrão

> Fale com a CBN pelo WhatsApp

Complemento:

> Link na bio

## Fluxo operacional

1. Pauta registrada no `Calendário Meta`.
2. Conceito e roteiro aprovados.
3. Imagens geradas individualmente.
4. Legenda revisada.
5. Aprovação humana registrada.
6. Conteúdo programado manualmente.
7. Após publicação, registrar status, horário, IDs e eventual erro.
8. Quando a automação estiver pronta, o n8n deverá ler somente itens aprovados, aplicar idempotência e registrar o resultado.

## Regras de segurança e conformidade

- Não inventar taxas, valores, prazos ou condições.
- Não prometer aprovação, economia ou liberação imediata.
- Não usar dados reais de clientes.
- Não expor token, App Secret, código de verificação ou credenciais.
- Não publicar rascunho automaticamente.
- Não alterar a conta Meta, conectar número ou ativar anúncio pago sem autorização explícita.

## Checklist antes de programar

- [ ] Proporção correta.
- [ ] Todas as páginas com a mesma dimensão.
- [ ] Ortografia revisada.
- [ ] Logo oficial correta.
- [ ] Informações verificadas.
- [ ] Sem promessas ou dados inventados.
- [ ] Legenda aprovada.
- [ ] CTA e aviso legal presentes quando necessários.
- [ ] Ordem do carrossel conferida.
- [ ] Registro atualizado no Calendário Meta.
