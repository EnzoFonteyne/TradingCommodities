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

# Buyer funds checked
event BuyerFundsChecked:
    buyer: address
    amount: uint256
    payment_token: address
    event_time: uint256

# Evento para notificar que a due diligence foi finalizada
event DueDiligneceFinalized:
    buyer: address
    seller: address

# ---------------------------------------------------
# Variáveis e eventos da negociação do contrato SPA

struct SPA_terms:
    commodity: String[100] # Nome da commodity
    commodity_origin: String[100] # Origem da commodity (país)
    port_of_loading: String[100] # Porto de carregamento
    port_of_discharge: String[100] # Porto de descarga
    specifications: String[300] # Especificações da commodity
    total_qty: uint256 # Quantidade total em MT (metric tons)
    monthly_qty: uint256 # Quantidade mensal em MT
    price_per_mt: uint256 # Preço por tonelada métrica (MT)
    incoterm: String[10] # Incoterm (ex. FOB, CIF, etc.)
    payment_terms: bool # Termos de pagamento (SPOT ou com adiantamnento)
    upfront_payment_pct: uint256 # Quantidade de pagamento adiantado em porcentagem (0-100)
    trial_shipment: bool # Se houver embarque de teste
    trial_shipment_qty: uint256 # Quantidade do embarque de teste em MT
    inspection_agency: String[100] # Agência de inspeção
    buyer_addres: address # Endereço do comprador
    seller_address: address # Endereço do vendedor
    attachments_hash: bytes32  # Hash dos anexos (pode ser um IPFS hash)
    created_at: uint256 # Timestamp da criação da proposta
    proposer: address # Endereço do proponente (quem fez a proposta)
    auditor: address # Endereço do auditor externo
    auditor_commission_pct: bool # Se a comissão do auditor é percentual
    auditor_commission: uint256 # Comissão do auditor por proposta

auditor: public(address)                    # endereço do auditor externo
current_status: public(String[20])       # status atual da negociação

proposals: public(DynArray[Proposal, 20]) # lista de propostas feitas durante a negociação
SPA_signed_by_buyer: public(bool) # comprador assinou o SPA
SPA_signed_by_seller: public(bool) # vendedor assinou o SPA
#audit_passed: public(bool) -----> será substituido por due_diligence_finalized

# Flags para verificar produto e embarque
POP_approved: public(bool)                # auditor confirmou prova de produto do vendedor
BL_issued: public(bool)            # auditor certificou embarque (prod. carregado)

is_funded: public(bool)
payment_amount: public(uint256)
payment_token: public(address)
payment_released: public(bool)

usdt_address: address = 0xdAC17F958D2ee523a2206206994597C13D831ec7  # endereço do USDT na Ethereum mainnet

event NegotiationInitiated:
    proposer: address
    event_time: uint256

event SellerQuote:
    proposer: address
    index: uint256
    event_time: uint256

event AuditorSet:
    auditor: address
    auditor_commission: uint256
    auditor_commission_pct: bool
    event_time: uint256

event NewPaymentTerms:
    new_payment_terms: bool
    new_upfront_payment_pct: uint256
    new_price_per_mt: uint256
    proposer: address
    event_time: uint256

event NegotiationAccepted:
    accepter: address
    event_time: uint256

event NegotiationFinalized:
    event_time: uint256
    final_proposal_hash: bytes32

event NegotiationRejected:
    rejector: address
    event_time: uint256

event MockAuditPerformed:
    initiator: address
    event_time: uint256
    result: String[20]

# Eventos novos para auditor
event POP_done:
    auditor: address
    event_time: uint256

event BL_done:
    auditor: address
    event_time: uint256

event PaymentDeposited:
    sender: address
    amount: uint256
    token: address
    event_time: uint256

event PaymentReleased:
    recipient: address
    amount: uint256
    token: address
    event_time: uint256

# Inicializa o contrato com os endereços do KYC, comprador e vendedor
@external
def __init__(kyc_address: address, buyer_: address, seller_: address, _auditor: address, _payment_token: address):
    self.kyc_contract = kyc_address
    self.buyer = buyer_
    self.seller = seller_
    self.auditor = _auditor

    # Seller tem que ser owner do KYC
    assert KYC(kyc_address).owner() == seller_, "Seller must be owner of KYC"

    # Verifica se ambos estão registrados no KYC
    assert KYC(kyc_address).get_company_name(buyer_) != "", "Buyer not registered in KYC"
    assert KYC(kyc_address).get_company_name(seller_) != "", "Seller not registered in KYC"

    self.buyer_info_signed = False
    self.seller_info_signed = False
    self.due_diligence_finalized = False

    # Inicializa as variáveis de negociação
    self.payment_token = _payment_token

    self.current_status = "OPEN"
    self.SPA_signed_by_buyer = False
    self.SPA_signed_by_seller = False

    self.POP_approved = False
    self.BL_issued = False

    self.is_funded = False
    self.payment_amount = 0
    self.payment_released = False

# Funções para assinar as informações do comprador e vendedor
@external
def sign_info_as_buyer():
    assert msg.sender == self.buyer, "Only buyer can sign"
    self.buyer_info_signed = True

@external
def sign_info_as_seller():
    assert msg.sender == self.seller, "Only seller can sign"
    self.seller_info_signed = True

@external
def check_buyer_funds(_payment_token: address):
    """
    Verifica se o comprador tem fundos suficientes para a negociação.
    """
    assert msg.sender == self.seller, "Only seller can check funds"
    assert _payment_token == self.payment_token, "Invalid payment token"       

    # Aqui você pode adicionar lógica para verificar os fundos do comprador
    # Por exemplo, usando um contrato ERC20 para verificar o saldo
    interface ERC20:
        def balanceOf(account: address) -> uint256: view

    buyer_balance: uint256 = ERC20(self.payment_token).balanceOf(self.buyer)
    log BuyerFundsChecked(self.buyer, buyer_balance, self.payment_token, block.timestamp)
    return buyer_balance

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

@external
def initiateNegotiation(
    commodity: String[100],
    commodity_origin: String[100],
    port_of_discharge: String[100], # Porto de descarga
    specifications: String[300], # Especificações da commodity
    total_qty: uint256, # Quantidade total em MT (metric tons)
    monthly_qty: uint256, # Quantidade mensal em MT
    incoterm: String[10], # Incoterm (ex. FOB, CIF, etc.)
    trial_shipment: bool, # Se houver embarque de teste
    trial_shipment_qty: uint256, # Quantidade do embarque de teste em MT
    buyer_address: address # Endereço do comprador
):
    assert msg.sender == self.buyer, "Only buyer can initiate"
    assert self.due_diligence_finalized, "Due diligence not finalized"
    assert buyer_address == self.buyer, "Buyer address mismatch"
    assert self.current_status == "OPEN", "Negotiation already started"

    # sempre que houver nova proposta, zera as aprovações anteriores
    self.SPA_signed_by_buyer = False
    self.SPA_signed_by_seller = False

    self.POP_approved = False
    self.BL_issued = False

    proposal: Proposal = SPA_terms({
        commodity: commodity,
        commodity_origin: commodity_origin,
        port_of_discharge: port_of_discharge,
        specifications: specifications,
        total_qty: total_qty,
        monthly_qty: monthly_qty,
        incoterm: incoterm,
        trial_shipment: trial_shipment,
        trial_shipment_qty: trial_shipment_qty,
        buyer_address: buyer_address,
        created_at: block.timestamp,
        proposer: msg.sender
    })
    self.proposals.append(proposal)
    self.current_status = "NEGOTIATING"
    log NegotiationInitiated(msg.sender, block.timestamp)

@external
def seller_quote(
    commodity_origin: String[100],
    port_of_loading: String[100], # Porto de carregamento
    price_per_mt: uint256, # Preço por tonelada métrica (MT)
    payment_terms: bool, # Termos de pagamento (True = SPOT ou False = adiantamento)
    upfront_payment_pct: uint256 = 30, # Quantidade de pagamento adiantado em porcentagem (0-100) define 30 como padrao
    inspection_agency: String[100], # Agência de inspeção
    seller_address: address  # Endereço do vendedor
):
    assert msg.sender == self.seller, "Only seller can quote"
    assert self.due_diligence_finalized, "Due diligence not finalized"
    assert seller_address == self.seller, "Buyer address mismatch"
    assert self.current_status == "NEGOTIATING", "Negotiation not active"

    # sempre que houver nova proposta, zera as aprovações anteriores
    self.SPA_signed_by_buyer = False
    self.SPA_signed_by_seller = False

    self.POP_approved = False
    self.BL_issued = False

    current_proposal = self.proposals[len(self.proposals)-1]

    current_proposal.commodity_origin = commodity_origin
    current_proposal.port_of_loading = port_of_loading
    current_proposal.price_per_mt = price_per_mt

    if payment_terms:
        current_proposal.payment_terms = True  # SPOT payment
        current_proposal.upfront_payment_pct = 0  # No advance payment
    else:
        assert upfront_payment_pct > 0 and upfront_payment_pct <= 100, "Invalid upfront payment percentage"
        current_proposal.upfront_payment_pct = upfront_payment_pct  # Set advance payment percentage
        current_proposal.payment_terms = False  # Payment with advance

    current_proposal.inspection_agency = inspection_agency
    current_proposal.seller_address = seller_address
    current_proposal.created_at = block.timestamp
    current_proposal.proposer = msg.sender
    
    self.proposals.append(current_proposal)
    log SellerQuote(msg.sender, len(self.proposals) - 1, block.timestamp)

@external
def set_auditor(_auditor: address, _auditor_commission: uint256, _auditor_commission_pct: bool):
    """
    Define o auditor externo e sua comissão.
    """
    assert msg.sender == self.buyer or msg.sender == self.seller, "Only buyer or seller can set auditor"
    assert _auditor != ZERO_ADDRESS, "Invalid auditor address"
    assert self.current_status == "NEGOTIATING", "Negotiation not active"
    assert self.due_diligence_finalized, "Due diligence not finalized"

    # sempre que houver nova proposta, zera as aprovações anteriores
    self.SPA_signed_by_buyer = False
    self.SPA_signed_by_seller = False

    self.POP_approved = False
    self.BL_issued = False
    
    current_proposal = self.proposals[len(self.proposals)-1]

    self.auditor = _auditor_commission

    current_proposal.auditor = _auditor

    if _auditor_commission_pct:
        assert _auditor_commission > 0 and _auditor_commission <= 100, "Invalid commission percentage"
        current_proposal.auditor_commission = _auditor_commission
        current_proposal.auditor_commission_pct = _auditor_commission_pct
    else:
        assert _auditor_commission >= 0, "Commission must be non-negative if fixed amount"
        current_proposal.auditor_commission = _auditor_commission
        current_proposal.auditor_commission_pct = _auditor_commission_pct

    current_proposal.created_at = block.timestamp
    current_proposal.proposer = msg.sender
    
    self.proposals.append(current_proposal)

    log AuditorSet(_auditor, _auditor_commission, _auditor_commission_pct, block.timestamp)

def change_payment_terms(new_payment_terms: bool, new_upfront_payment_pct: uint256, new_price_per_mt: uint256):
    """
    Altera os termos de pagamento da negociação.
    """
    assert msg.sender == self.buyer or msg.sender == self.seller, "Only buyer or seller can change payment terms"
    assert self.current_status == "NEGOTIATING", "Negotiation not active"
    assert self.due_diligence_finalized, "Due diligence not finalized"

    # sempre que houver nova proposta, zera as aprovações anteriores
    self.SPA_signed_by_buyer = False
    self.SPA_signed_by_seller = False

    self.POP_approved = False
    self.BL_issued = False

    current_proposal = self.proposals[len(self.proposals)-1]

    if new_payment_terms:
        current_proposal.payment_terms = True  # SPOT payment
        current_proposal.upfront_payment_pct = 0  # No advance payment
    else:
        assert new_upfront_payment_pct > 0 and new_upfront_payment_pct <= 100, "Invalid upfront payment percentage"
        current_proposal.upfront_payment_pct = new_upfront_payment_pct  # Set advance payment percentage
        current_proposal.payment_terms = False  # Payment with advance

    current_proposal.price_per_mt = new_price_per_mt  # Update price per MT
    current_proposal.created_at = block.timestamp
    current_proposal.proposer = msg.sender
    
    self.proposals.append(current_proposal)
    log NewPaymentTerms(new_payment_terms, new_upfront_payment_pct, new_price_per_mt, msg.sender, block.timestamp)

def set_new_proposal(
    commodity: String[100], # Nome da commodity
    commodity_origin: String[100], # Origem da commodity (país)
    port_of_loading: String[100], # Porto de carregamento
    port_of_discharge: String[100], # Porto de descarga
    specifications: String[300], # Especificações da commodity
    total_qty: uint256, # Quantidade total em MT (metric tons)
    monthly_qty: uint256, # Quantidade mensal em MT
    price_per_mt: uint256, # Preço por tonelada métrica (MT)
    incoterm: String[10], # Incoterm (ex. FOB, CIF, etc.)
    payment_terms: bool, # Termos de pagamento (SPOT ou com adiantamnento)
    upfront_payment_pct: uint256, # Quantidade de pagamento adiantado em porcentagem (0-100)
    trial_shipment: bool, # Se houver embarque de teste
    trial_shipment_qty: uint256, # Quantidade do embarque de teste em MT
    inspection_agency: String[100], # Agência de inspeção
    buyer_addres: address, # Endereço do comprador
    seller_address: address, # Endereço do vendedor
    attachments_hash: bytes32,  # Hash dos anexos (pode ser um IPFS hash)
    created_at: uint256, # Timestamp da criação da proposta
    proposer: address, # Endereço do proponente (quem fez a proposta)
    auditor: address, # Endereço do auditor externo
    auditor_commission_pct: bool, # Se a comissão do auditor é percentual
    auditor_commission: uint256, # Comissão do auditor por proposta
):
    assert msg.sender == self.buyer or msg.sender == self.seller, "Only buyer or seller can set new proposal"
    assert self.due_diligence_finalized, "Due diligence not finalized"
    assert self.current_status == "NEGOTIATING", "Negotiation not active"

    # sempre que houver nova proposta, zera as aprovações anteriores
    self.SPA_signed_by_buyer = False
    self.SPA_signed_by_seller = False

    self.POP_approved = False
    self.BL_issued = False

    proposal: Proposal = SPA_terms({
        commodity: commodity,
        commodity_origin: commodity_origin,
        port_of_loading: port_of_loading,
        port_of_discharge: port_of_discharge,
        specifications: specifications,
        total_qty: total_qty,
        monthly_qty: monthly_qty,
        price_per_mt: price_per_mt,
        incoterm: incoterm,
        payment_terms: payment_terms,
        upfront_payment_pct: upfront_payment_pct,
        trial_shipment: trial_shipment,
        trial_shipment_qty: trial_shipment_qty,
        inspection_agency: inspection_agency,
        buyer_address: buyer_addres,
        seller_address: seller_address,
        attachments_hash: attachments_hash,
        created_at: created_at,
        proposer: proposer,
        auditor: auditor,
        auditor_commission_pct: auditor_commission_pct,
        auditor_commission: auditor_commission
    })


@external
def acceptNegotiation():
    assert msg.sender == self.buyer or msg.sender == self.seller, "Only buyer or seller"
    assert self.due_diligence_finalized, "Due diligence not finalized"
    assert self.current_status == "NEGOTIATING", "Negotiation not active"

    current_proposal = self.proposals[len(self.proposals)-1]

    for variaveis in current_proposal:
        assert variaveis != "", "All proposal fields must be filled"

    if msg.sender == self.buyer:
        self.SPA_signed_by_buyer = True
    else:
        self.SPA_signed_by_seller = True

    log NegotiationAccepted(msg.sender, block.timestamp)

    if self.accepted_by_buyer and self.accepted_by_seller:
        self.current_status = "FINALIZED"
        final_hash: bytes32 = keccak256(concat(convert(len(self.proposals)-1, bytes32), convert(block.timestamp, bytes32)))
        log NegotiationFinalized(block.timestamp, final_hash)

@external
def rejectNegotiation():
    assert msg.sender == self.buyer or msg.sender == self.seller, "Only buyer or seller"
    self.current_status = "REJECTED"
    log NegotiationRejected(msg.sender, block.timestamp)

@external
def InitiateContract():
    """
    Auditor inicia o contrato SPA, verificando se as informações do comprador e vendedor foram assinadas.
    """
    assert msg.sender == self.auditor, "Only auditor can initiate contract"
    assert self.buyer_info_signed and self.seller_info_signed, "Both parties must sign info"
    assert self.due_diligence_finalized, "Due diligence not finalized"
    assert self.current_status == "FINALIZED", "Negotiation not finalized"

    self.current_status = "RUNNING"
    # Aqui você pode adicionar a lógica para iniciar o contrato SPA
    # Por exemplo, transferir fundos, emitir documentos, etc.

    log ContractInitiated(self.buyer, self.seller, block.timestamp)
    
