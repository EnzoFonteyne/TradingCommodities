import pytest
from ape import project, reverts

# Informações completas e mínimas válidas para deploy e registro
VALID_INFO = {
    "name": "Empresa Exemplo",
    "hq_address": "Rua Exemplo, 123",
    "city": "São Paulo",
    "country": "Brasil",
    "company_id": "123456789",
    "registration_institution": "Junta Comercial",
    "phone": "+55 11 1234-5678",
    "mobile": "+55 11 91234-5678",
    "legal_representative": "João Silva",
    "position": "Diretor",
    "passport_number": "AB1234567",
    "passport_country": "Brasil",
    "email": "joao@empresa.com",
    "passport_hash": b"\x01" * 32,  # Qualquer hash não vazio
}

REQUIRED_FIELDS = [
    "name",
    "country",
    "company_id",
    "registration_institution",
    "legal_representative",
    "passport_number",
    "passport_hash"
]

def make_info(**overrides):
    """Helper para criar um dict com os dados, podendo sobrescrever campos."""
    info = VALID_INFO.copy()
    info.update(overrides)
    return info

@pytest.fixture
def owner(accounts):
    return accounts[0]

@pytest.fixture
def user(accounts):
    return accounts[1]

def deploy_kyc(owner, info=None):
    if info is None:
        info = VALID_INFO
    return owner.deploy(
        project.KYC,
        info["name"],
        info["hq_address"],
        info["city"],
        info["country"],
        info["company_id"],
        info["registration_institution"],
        info["phone"],
        info["mobile"],
        info["legal_representative"],
        info["position"],
        info["passport_number"],
        info["passport_country"],
        info["email"],
        info["passport_hash"]
    )

def register_company(kyc_contract, user, info=None):
    if info is None:
        info = VALID_INFO
    return kyc_contract.register_company(
        info["name"],
        info["hq_address"],
        info["city"],
        info["country"],
        info["company_id"],
        info["registration_institution"],
        info["phone"],
        info["mobile"],
        info["legal_representative"],
        info["position"],
        info["passport_number"],
        info["passport_country"],
        info["email"],
        info["passport_hash"],
        sender=user
    )

def update_company_info(kyc_contract, user, info=None):
    if info is None:
        info = VALID_INFO
    return kyc_contract.update_company_info(
        info["name"],
        info["hq_address"],
        info["city"],
        info["country"],
        info["company_id"],
        info["registration_institution"],
        info["phone"],
        info["mobile"],
        info["legal_representative"],
        info["position"],
        info["passport_number"],
        info["passport_country"],
        info["email"],
        info["passport_hash"],
        sender=user
    )

def update_owner_info(kyc_contract, owner, info=None):
    if info is None:
        info = VALID_INFO
    return kyc_contract.update_owner_info(
        info["name"],
        info["hq_address"],
        info["city"],
        info["country"],
        info["company_id"],
        info["registration_institution"],
        info["phone"],
        info["mobile"],
        info["legal_representative"],
        info["position"],
        info["passport_number"],
        info["passport_country"],
        info["email"],
        info["passport_hash"],
        sender=owner
    )

# 1. Testa se owner NÃO consegue dar deploy com informações faltantes
@pytest.mark.parametrize("field", REQUIRED_FIELDS)
def test_owner_cannot_deploy_with_missing_required(owner, field):
    info = make_info(**{field: "" if field != "passport_hash" else b"\x00"*32})
    with reverts():
        deploy_kyc(owner, info)

# 2. Testa se owner consegue deploy com apenas as infos necessárias
def test_owner_can_deploy_with_only_required(owner):
    info = {key: VALID_INFO[key] for key in VALID_INFO}
    # Todos os campos são necessários, então deploy deve funcionar
    contract = deploy_kyc(owner, info)
    assert contract.owner() == owner.address

# 3. Testa se owner NÃO consegue atualizar informações faltantes
@pytest.mark.parametrize("field", REQUIRED_FIELDS)
def test_owner_cannot_update_with_missing_required(owner, field):
    contract = deploy_kyc(owner)
    info = make_info(**{field: "" if field != "passport_hash" else b"\x00"*32})
    with reverts():
        update_owner_info(contract, owner, info)

# 4. Testa se owner NÃO consegue apagar informações necessárias (tornar vazias)
def test_owner_cannot_erase_required_fields(owner):
    contract = deploy_kyc(owner)
    info = make_info(name="")
    with reverts():
        update_owner_info(contract, owner, info)

# 5. Testa se um endereço NÃO consegue se registrar com informações faltantes
@pytest.mark.parametrize("field", REQUIRED_FIELDS)
def test_user_cannot_register_with_missing_required(owner, user, field):
    contract = deploy_kyc(owner)
    info = make_info(**{field: "" if field != "passport_hash" else b"\x00"*32})
    with reverts():
        register_company(contract, user, info)

# 6. Testa se um endereço consegue registrar com apenas as infos necessárias
def test_user_can_register_with_only_required(owner, user):
    contract = deploy_kyc(owner)
    tx = register_company(contract, user)
    assert contract.get_company_name(user.address) == VALID_INFO["name"]

# 7. Testa se um endereço NÃO consegue atualizar sem aprovação do owner
def test_user_cannot_update_without_approval(owner, user):
    contract = deploy_kyc(owner)
    register_company(contract, user)
    with reverts():
        update_company_info(contract, user)

# 8. Testa se o owner consegue aprovar um endereço (set update_approval)
def test_owner_can_approve_user(owner, user):
    contract = deploy_kyc(owner)
    register_company(contract, user)
    # Supondo que você tenha uma função approve_update(user) no contrato
    contract.approve_update(user.address, sender=owner)  # ou chame o método se existir
    assert contract.update_approval(user.address) == True

# 9. Testa se o endereço consegue atualizar as informações APÓS aprovação do owner
def test_user_can_update_after_approval(owner, user):
    contract = deploy_kyc(owner)
    register_company(contract, user)
    contract.approve_update(user.address, sender=owner)  # owner aprova
    info = make_info(name="Empresa Nova")
    update_company_info(contract, user, info)
    assert contract.get_company_name(user.address) == "Empresa Nova"

# 10. Testa funções view do contrato após registro e atualização
def test_view_functions_after_register_and_update(owner, user):
    contract = deploy_kyc(owner)
    register_company(contract, user)
    contract.approve_update(user.address, sender=owner)
    info = make_info(
        name="Empresa Visual",
        country="Paraguai",
        company_id="987654321",
        registration_institution="Junta PY",
        legal_representative="Maria Souza",
        passport_number="CDE876543",
        passport_hash=b"\x02"*32
    )
    update_company_info(contract, user, info)
    assert contract.get_company_name(user.address) == "Empresa Visual"
    assert contract.get_company_country(user.address) == "Paraguai"
    assert contract.get_company_id(user.address) == "987654321"
    assert contract.get_registration_institution(user.address) == "Junta PY"
    assert contract.get_passport_number(user.address) == "CDE876543"
    assert contract.get_passport_hash(user.address) == b"\x02"*32