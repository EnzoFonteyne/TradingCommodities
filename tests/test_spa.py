import pytest
from ape import project, reverts

@pytest.fixture
def seller(accounts):
    return accounts[0]

@pytest.fixture
def buyer(accounts):
    return accounts[1]

@pytest.fixture
def outsider(accounts):
    return accounts[2]

@pytest.fixture
def kyc_contract(seller, project):
    # O seller é o owner do KYC e seus dados já estão registrados
    return seller.deploy(
        project.KYC,
        "Seller Corp", "Rua Seller", "SP", "Brasil", "IDSELLER", "Junta",
        "+55 11 1234-5678", "+55 11 91234-5678",
        "João Seller", "Diretor", "PSELLER", "Brasil", "seller@email.com", b"\x01" * 32
    )

def register_buyer(kyc_contract, buyer):
    kyc_contract.register_company(
        "Buyer Corp", "Rua Buyer", "RJ", "Brasil", "IDBUYER", "Junta",
        "+55 21 1234-5678", "+55 21 91234-5678",
        "Maria Buyer", "Diretora", "PBUYER", "Brasil", "buyer@email.com", b"\x02" * 32,
        sender=buyer
    )

def test_spa_fails_if_seller_not_owner_of_kyc(kyc_contract, buyer, outsider, project):
    register_buyer(kyc_contract, buyer)
    with reverts("Seller must be owner of KYC"):
        outsider.deploy(project.SPA, kyc_contract.address, buyer.address, outsider.address)

def test_spa_fails_if_buyer_not_registered(kyc_contract, seller, outsider, project):
    # Buyer (outsider) não está registrado
    with reverts("Buyer not registered in KYC"):
        seller.deploy(project.SPA, kyc_contract.address, outsider.address, seller.address)

def test_spa_does_not_finalize_without_seller_signature(kyc_contract, seller, buyer, project):
    register_buyer(kyc_contract, buyer)
    spa = seller.deploy(project.SPA, kyc_contract.address, buyer.address, seller.address)
    spa.sign_info_as_buyer(sender=buyer)
    with reverts("Both parties must sign"):
        spa.finalize_due_diligence(sender=seller)

def test_spa_does_not_finalize_without_buyer_signature(kyc_contract, seller, buyer, project):
    register_buyer(kyc_contract, buyer)
    spa = seller.deploy(project.SPA, kyc_contract.address, buyer.address, seller.address)
    spa.sign_info_as_seller(sender=seller)
    with reverts("Both parties must sign"):
        spa.finalize_due_diligence(sender=seller)

def test_spa_finalizes_and_saves_data(kyc_contract, seller, buyer, project):
    register_buyer(kyc_contract, buyer)
    spa = seller.deploy(project.SPA, kyc_contract.address, buyer.address, seller.address)
    spa.sign_info_as_buyer(sender=buyer)
    spa.sign_info_as_seller(sender=seller)
    tx = spa.finalize_due_diligence(sender=seller)

    # Buyer info snapshot
    buyer_info = spa.buyer_info()
    assert buyer_info.name == "Buyer Corp"
    assert buyer_info.company_id == "IDBUYER"
    assert buyer_info.legal_representative == "Maria Buyer"

    # Seller info snapshot (owner do KYC)
    seller_info = spa.seller_info()
    assert seller_info.name == "Seller Corp"
    assert seller_info.company_id == "IDSELLER"
    assert seller_info.legal_representative == "João Seller"

    # Verifica o evento DueDiligneceFinalized
    logs = [log for log in tx.events if log.event_name == "DueDiligneceFinalized"]
    assert len(logs) == 1
    assert logs[0].buyer == buyer.address
    assert logs[0].seller == seller.address
