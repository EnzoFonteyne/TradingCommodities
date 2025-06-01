# SPDX-License-Identifier: MIT
# @title TradeNegotiationContract - Vyper (with Payment Escrow)
# @version ^0.3.3

from vyper.interfaces import ERC20

struct Proposal:
    commodity: String[100]
    commodity_origin: String[100]
    specifications: String[300]
    total_qty: uint256
    monthly_qty: uint256
    price_per_mt: uint256
    incoterm: String[10]
    payment_terms: String[200]
    inspection_agency: String[100]
    buyer_bank_info: String[200]
    seller_bank_info: String[200]
    attachments_hash: bytes32
    created_at: uint256
    proposer: address
    doc_type: String[10]

buyer: public(address)
seller: public(address)
current_status: public(String[20])

proposals: public(DynArray[Proposal, 20])
accepted_by_buyer: public(bool)
accepted_by_seller: public(bool)
audit_passed: public(bool)

is_funded: public(bool)
payment_amount: public(uint256)
payment_token: public(address)
payment_released: public(bool)

event NegotiationInitiated:
    proposer: address
    event_time: uint256

event CounterOfferSubmitted:
    proposer: address
    index: uint256
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

@external
def __init__(_seller: address, _payment_token: address):
    self.seller = _seller
    self.buyer = msg.sender
    self.current_status = "OPEN"
    self.accepted_by_buyer = False
    self.accepted_by_seller = False
    self.audit_passed = False
    self.is_funded = False
    self.payment_amount = 0
    self.payment_token = _payment_token
    self.payment_released = False

@external
def initiateNegotiation(
    commodity: String[100],
    commodity_origin: String[100],
    specifications: String[300],
    total_qty: uint256,
    monthly_qty: uint256,
    price_per_mt: uint256,
    incoterm: String[10],
    payment_terms: String[200],
    inspection_agency: String[100],
    buyer_bank_info: String[200],
    attachments_hash: bytes32
):
    assert msg.sender == self.buyer, "Only buyer can initiate"
    assert self.current_status == "OPEN", "Negotiation already started"
    proposal: Proposal = Proposal({
        commodity: commodity,
        commodity_origin: commodity_origin,
        specifications: specifications,
        total_qty: total_qty,
        monthly_qty: monthly_qty,
        price_per_mt: price_per_mt,
        incoterm: incoterm,
        payment_terms: payment_terms,
        inspection_agency: inspection_agency,
        buyer_bank_info: buyer_bank_info,
        seller_bank_info: "",
        attachments_hash: attachments_hash,
        created_at: block.timestamp,
        proposer: msg.sender,
        doc_type: "ICPO"
    })
    self.proposals.append(proposal)
    self.current_status = "NEGOTIATING"
    log NegotiationInitiated(msg.sender, block.timestamp)

@external
def submitCounterOffer(
    commodity: String[100],
    commodity_origin: String[100],
    specifications: String[300],
    total_qty: uint256,
    monthly_qty: uint256,
    price_per_mt: uint256,
    incoterm: String[10],
    payment_terms: String[200],
    inspection_agency: String[100],
    buyer_bank_info: String[200],
    seller_bank_info: String[200],
    attachments_hash: bytes32,
    doc_type: String[10]
):
    assert msg.sender == self.buyer or msg.sender == self.seller, "Only buyer or seller"
    assert self.current_status == "NEGOTIATING", "Negotiation not active"
    proposal: Proposal = Proposal({
        commodity: commodity,
        commodity_origin: commodity_origin,
        specifications: specifications,
        total_qty: total_qty,
        monthly_qty: monthly_qty,
        price_per_mt: price_per_mt,
        incoterm: incoterm,
        payment_terms: payment_terms,
        inspection_agency: inspection_agency,
        buyer_bank_info: buyer_bank_info,
        seller_bank_info: seller_bank_info,
        attachments_hash: attachments_hash,
        created_at: block.timestamp,
        proposer: msg.sender,
        doc_type: doc_type
    })
    self.proposals.append(proposal)
    self.accepted_by_buyer = False
    self.accepted_by_seller = False
    self.audit_passed = False
    log CounterOfferSubmitted(msg.sender, len(self.proposals)-1, block.timestamp)

@external
def acceptNegotiation():
    assert msg.sender == self.buyer or msg.sender == self.seller, "Only buyer or seller"
    assert self.audit_passed, "Audit/compliance not passed"
    if msg.sender == self.buyer:
        self.accepted_by_buyer = True
    else:
        self.accepted_by_seller = True
    log NegotiationAccepted(msg.sender, block.timestamp)
    if self.accepted_by_buyer and self.accepted_by_seller:
        self.current_status = "FINALIZED"
        # Simple hash using the proposal index and timestamp
        final_hash: bytes32 = keccak256(concat(convert(len(self.proposals)-1, bytes32), convert(block.timestamp, bytes32)))
        log NegotiationFinalized(block.timestamp, final_hash)

@external
def rejectNegotiation():
    assert msg.sender == self.buyer or msg.sender == self.seller, "Only buyer or seller"
    self.current_status = "REJECTED"
    log NegotiationRejected(msg.sender, block.timestamp)

@external
@view
def getNegotiationHistory() -> DynArray[Proposal, 20]:
    return self.proposals

@external
@view
def getCurrentProposal() -> Proposal:
    return self.proposals[len(self.proposals)-1]

@external
def mockAuditCompliance():
    self.audit_passed = True
    log MockAuditPerformed(msg.sender, block.timestamp, "SUCCESS")

@external
@payable
def depositPayment(amount: uint256 = 0):
    assert msg.sender == self.buyer, "Only buyer can deposit"
    assert self.current_status == "FINALIZED", "Negotiation must be finalized"
    assert not self.is_funded, "Already funded"
    if self.payment_token == ZERO_ADDRESS:
        assert msg.value > 0, "ETH value required"
        self.payment_amount = msg.value
    else:
        assert amount > 0, "Token amount required"
        ERC20(self.payment_token).transferFrom(msg.sender, self, amount)
        self.payment_amount = amount
    self.is_funded = True
    log PaymentDeposited(msg.sender, self.payment_amount, self.payment_token, block.timestamp)

@external
def releasePayment():
    assert self.is_funded, "Payment not funded"
    assert not self.payment_released, "Already released"
    if self.payment_token == ZERO_ADDRESS:
        send(self.seller, self.payment_amount)
    else:
        ERC20(self.payment_token).transfer(self.seller, self.payment_amount)
    self.payment_released = True
    log PaymentReleased(self.seller, self.payment_amount, self.payment_token, block.timestamp)
