# KYC Smart Contract

Este projeto implementa um contrato inteligente de KYC (Know Your Customer) desenvolvido em [Vyper](https://vyper.readthedocs.io/), voltado para aplicações de comércio internacional e validação de identidade empresarial em blockchain. Ele foi projetado para registrar, auditar e validar informações de empresas envolvidas em transações comerciais digitais.

## 📌 Objetivo

O contrato tem como objetivo:

- Substituir processos tradicionais de verificação de identidade de empresas em contratos comerciais (ex: SPA - Sales and Purchase Agreement).
- Garantir integridade e imutabilidade dos dados registrados.
- Facilitar a auditoria e due diligence por meio de funções públicas e eventos registrados on-chain.
- Permitir a atualização de dados de forma segura, somente com aprovação do `owner`.

## 🔐 Funcionalidades

### Registro de Empresas

Empresas podem registrar-se com dados obrigatórios e opcionais, como:

- Nome
- Endereço da sede
- País e cidade
- Número de identificação e instituição de registro
- Representante legal, passaporte e país de emissão
- Hash do passaporte (usado para validação via IPFS ou similar)
- Contato telefônico e email

### Atualização Segura

- Apenas o `owner` pode aprovar solicitações de atualização de dados.
- Nenhuma atualização será feita se campos obrigatórios estiverem em branco.
- Todas as alterações são registradas por meio de eventos (`logs`).

### Consulta/Auditoria

Funções de leitura pública permitem acessar informações sensíveis para auditoria:

- `get_passport_hash`
- `get_passport_number`
- `get_passport_country`
- `get_company_id`
- `get_registration_institution`
- `get_company_name`, `get_company_country`, entre outras.

### Eventos

Os seguintes eventos são emitidos:

- `CompanyRegistered`: empresa registrada.
- `CompanyUpdated`: dados da empresa atualizados.
- `OwnerUpdated`: dados do owner modificados.

## 🛠️ Tecnologias

- Vyper ^0.3.3
- Ethereum Virtual Machine (EVM)
- IPFS (para armazenamento externo do passaporte - recomendado)

## 📄 Licença

Licenciado sob a [MIT License](https://opensource.org/licenses/MIT).

## 📬 Contato

Para dúvidas ou sugestões, abra um *issue* ou entre em contato com o desenvolvedor responsável.
