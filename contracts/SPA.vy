# SPDX-License-Identifier: MIT
# @title SPA Smart Contract
# @version ^0.3.3

# Define as interfaces necessárias para interagir com o contrato KYC

interface KYC:
    def owner() -> address: view
    def get_company_name(user: address) -> String[100]: view
    def get_company_country(user: address) -> String[50]: view
    def get_company_id(user: address) -> String[50]: view
    def get_registration_institution(user: address) -> String[100]: view
    def get_passport_number(user: address) -> String[20]: view
    def get_passport_country(user: address) -> String[50]: view
    def get_passport_hash(user: address) -> bytes32: view
    def get_legal_representative_position(user: address) -> String[50]: view
    def get_legal_representative(user: address) -> String[100]: view

# Estrutura para capturar o snapshot dos dados do comprador e vendedor

struct CompanySnapshot:
    name: String[100]
    country: String[50]
    company_id: String[50]
    registration_institution: String[100]
    passport_number: String[20]
    passport_country: String[50]
    passport_hash: bytes32
    legal_representative: String[100]
    legal_representative_position: String[50]

# Variáveis para guardar os endereços do contrato KYC, comprador e vendedor,
kyc_contract: public(address)
buyer: public(address)
seller: public(address)

# Variáveis para controlar se as informações do comprador e vendedor foram assinadas
buyer_info_signed: public(bool)
seller_info_signed: public(bool)

# Variáveis para capturar os snapshots dos dados do comprador e vendedor
buyer_info: public(CompanySnapshot)
seller_info: public(CompanySnapshot)

# Variável para identificar se a due diligence foi finalizada
due_diligence_finalized: public(bool)

# Evento para notificar que a due diligence foi finalizada
event DueDiligneceFinalized:
    buyer: address
    seller: address

# Inicializa o contrato com os endereços do KYC, comprador e vendedor
@external
def __init__(kyc_address: address, buyer_: address, seller_: address):
    self.kyc_contract = kyc_address
    self.buyer = buyer_
    self.seller = seller_

    # Seller tem que ser owner do KYC
    assert KYC(kyc_address).owner() == seller_, "Seller must be owner of KYC"

    # Verifica se ambos estão registrados no KYC
    assert KYC(kyc_address).get_company_name(buyer_) != "", "Buyer not registered in KYC"
    assert KYC(kyc_address).get_company_name(seller_) != "", "Seller not registered in KYC"

    self.buyer_info_signed = False
    self.seller_info_signed = False
    self.due_diligence_finalized = False

# Funções para assinar as informações do comprador e vendedor
@external
def sign_info_as_buyer():
    assert msg.sender == self.buyer, "Only buyer can sign"
    self.buyer_info_signed = True

@external
def sign_info_as_seller():
    assert msg.sender == self.seller, "Only seller can sign"
    self.seller_info_signed = True

# Função para finalizar a due diligence, capturando os snapshots dos dados do comprador e vendedor
@external
def finalize_due_diligence():
    assert self.buyer_info_signed and self.seller_info_signed, "Both parties must sign"
    # Captura snapshot dos dados do comprador e vendedor
    self.buyer_info = CompanySnapshot({
        name: KYC(self.kyc_contract).get_company_name(self.buyer),
        country: KYC(self.kyc_contract).get_company_country(self.buyer),
        company_id: KYC(self.kyc_contract).get_company_id(self.buyer),
        registration_institution: KYC(self.kyc_contract).get_registration_institution(self.buyer),
        passport_number: KYC(self.kyc_contract).get_passport_number(self.buyer),
        passport_country: KYC(self.kyc_contract).get_passport_country(self.buyer),
        passport_hash: KYC(self.kyc_contract).get_passport_hash(self.buyer),
        legal_representative: KYC(self.kyc_contract).get_legal_representative(self.buyer),
        legal_representative_position: KYC(self.kyc_contract).get_legal_representative_position(self.buyer)
    })
    self.seller_info = CompanySnapshot({
        name: KYC(self.kyc_contract).get_company_name(self.seller),
        country: KYC(self.kyc_contract).get_company_country(self.seller),
        company_id: KYC(self.kyc_contract).get_company_id(self.seller),
        registration_institution: KYC(self.kyc_contract).get_registration_institution(self.seller),
        passport_number: KYC(self.kyc_contract).get_passport_number(self.seller),
        passport_country: KYC(self.kyc_contract).get_passport_country(self.seller),
        passport_hash: KYC(self.kyc_contract).get_passport_hash(self.seller),
        legal_representative: KYC(self.kyc_contract).get_legal_representative(self.seller),
        legal_representative_position: KYC(self.kyc_contract).get_legal_representative_position(self.seller)
    })
    self.due_diligence_finalized = True
    log DueDiligneceFinalized(self.buyer, self.seller)

# Inicia a negociação do contrato SPA
