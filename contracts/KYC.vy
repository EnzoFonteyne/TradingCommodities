# SPDX-License-Identifier: MIT
# @title KYC Smart Contract in Vyper
# @version ^0.3.3

from vyper.interfaces import ERC20

struct CompanyInfo:
    name: String[100]
    headquarters_address: String[200]
    city: String[50]
    country: String[50]
    company_id: String[50]
    registration_institution: String[100]
    phone: String[20]
    mobile: String[20]
    legal_representative: String[100]
    position: String[50]
    passport_number: String[20]
    passport_country: String[50]
    email: String[100]
    passport_hash: bytes32  # hash of the passport file (e.g., IPFS hash or Keccak256)

owner: public(address)
companies: public(HashMap[address, CompanyInfo])
update_approval: public(HashMap[address, bool])

# Event declarations
event CompanyRegistered:
    user: address
    company_id: String[50]

event CompanyUpdated:
    user: address
    company_id: String[50]

event OwnerUpdated:
    timestamp: uint256

event UpdateApproved:
    user: address
    timestamp: uint256


@external
@view
def get_passport_hash(user: address) -> bytes32:
    return self.companies[user].passport_hash

@external
@view
def get_passport_number(user: address) -> String[20]:
    return self.companies[user].passport_number

@external
@view
def get_passport_country(user: address) -> String[50]:
    return self.companies[user].passport_country
  
@external
@view
def get_company_name(user: address) -> String[100]:
    return self.companies[user].name
  
@external
@view
def get_company_country(user: address) -> String[50]:
    return self.companies[user].country

@external
@view
def get_company_id(user: address) -> String[50]:
    return self.companies[user].company_id

@external
@view
def get_registration_institution(user: address) -> String[100]:
    return self.companies[user].registration_institution

@external
@view
def get_legal_representative(user: address) -> String[100]:
    return self.companies[user].legal_representative

@external
@view
def get_legal_representative_position(user: address) -> String[50]:
    return self.companies[user].position

@external
def __init__(
    _name: String[100],
    _hq_address: String[200],
    _city: String[50],
    _country: String[50],
    _company_id: String[50],
    _registration_institution: String[100],
    _phone: String[20],
    _mobile: String[20],
    _legal_representative: String[100],
    _position: String[50],
    _passport_number: String[20],
    _passport_country: String[50],
    _email: String[100],
    _passport_hash: bytes32
):
    assert _name != "", "Name required"
    assert _country != "", "Country required"
    assert _company_id != "", "Company ID required"
    assert _registration_institution != "", "Registration institution required"
    assert _legal_representative != "", "Legal representative required"
    assert _passport_number != "", "Passport number required"
    assert _passport_hash != empty(bytes32), "Passport hash required"

    self.owner = msg.sender
    self.companies[self.owner] = CompanyInfo({
        name: _name,
        headquarters_address: _hq_address,
        city: _city,
        country: _country,
        company_id: _company_id,
        registration_institution: _registration_institution,
        phone: _phone,
        mobile: _mobile,
        legal_representative: _legal_representative,
        position: _position,
        passport_number: _passport_number,
        passport_country: _passport_country,
        email: _email,
        passport_hash: _passport_hash
    })
    log OwnerUpdated(block.timestamp)

@external
def update_owner_info(
    _name: String[100],
    _hq_address: String[200],
    _city: String[50],
    _country: String[50],
    _company_id: String[50],
    _registration_institution: String[100],
    _phone: String[20],
    _mobile: String[20],
    _legal_representative: String[100],
    _position: String[50],
    _passport_number: String[20],
    _passport_country: String[50],
    _email: String[100],
    _passport_hash: bytes32
):
    assert msg.sender == self.owner, "Only owner can update owner info"
    assert _name != "", "Name required"
    assert _country != "", "Country required"
    assert _company_id != "", "Company ID required"
    assert _registration_institution != "", "Registration institution required"
    assert _legal_representative != "", "Legal representative required"
    assert _passport_number != "", "Passport number required"
    assert _passport_hash != empty(bytes32), "Passport hash required"

    self.companies[self.owner] = CompanyInfo({
        name: _name,
        headquarters_address: _hq_address,
        city: _city,
        country: _country,
        company_id: _company_id,
        registration_institution: _registration_institution,
        phone: _phone,
        mobile: _mobile,
        legal_representative: _legal_representative,
        position: _position,
        passport_number: _passport_number,
        passport_country: _passport_country,
        email: _email,
        passport_hash: _passport_hash
    })
    log OwnerUpdated(block.timestamp)

@external
def register_company(
    _name: String[100],
    _hq_address: String[200],
    _city: String[50],
    _country: String[50],
    _company_id: String[50],
    _registration_institution: String[100],
    _phone: String[20],
    _mobile: String[20],
    _legal_representative: String[100],
    _position: String[50],
    _passport_number: String[20],
    _passport_country: String[50],
    _email: String[100],
    _passport_hash: bytes32
):
    assert _name != "", "Name required"
    assert _country != "", "Country required"
    assert _company_id != "", "Company ID required"
    assert _registration_institution != "", "Registration institution required"
    assert _legal_representative != "", "Legal representative required"
    assert _passport_number != "", "Passport number required"
    assert _passport_hash != empty(bytes32), "Passport hash required"
    assert self.companies[msg.sender].name == "", "Company already registered"
    assert msg.sender != self.owner, "Owner cannot register as a company"

    self.companies[msg.sender] = CompanyInfo({
        name: _name,
        headquarters_address: _hq_address,
        city: _city,
        country: _country,
        company_id: _company_id,
        registration_institution: _registration_institution,
        phone: _phone,
        mobile: _mobile,
        legal_representative: _legal_representative,
        position: _position,
        passport_number: _passport_number,
        passport_country: _passport_country,
        email: _email,
        passport_hash: _passport_hash
    })
    log CompanyRegistered(msg.sender, _company_id)

@external
def update_company_info(
    _name: String[100],
    _hq_address: String[200],
    _city: String[50],
    _country: String[50],
    _company_id: String[50],
    _registration_institution: String[100],
    _phone: String[20],
    _mobile: String[20],
    _legal_representative: String[100],
    _position: String[50],
    _passport_number: String[20],
    _passport_country: String[50],
    _email: String[100],
    _passport_hash: bytes32
):
    assert self.update_approval[msg.sender], "Update not approved by owner"
    assert _name != "", "Name required"
    assert _country != "", "Country required"
    assert _company_id != "", "Company ID required"
    assert _registration_institution != "", "Registration institution required"
    assert _legal_representative != "", "Legal representative required"
    assert _passport_number != "", "Passport number required"
    assert _passport_hash != empty(bytes32), "Passport hash required"

    self.update_approval[msg.sender] = False
    self.companies[msg.sender] = CompanyInfo({
        name: _name,
        headquarters_address: _hq_address,
        city: _city,
        country: _country,
        company_id: _company_id,
        registration_institution: _registration_institution,
        phone: _phone,
        mobile: _mobile,
        legal_representative: _legal_representative,
        position: _position,
        passport_number: _passport_number,
        passport_country: _passport_country,
        email: _email,
        passport_hash: _passport_hash
    })
    log CompanyUpdated(msg.sender, _company_id)

@external
def approve_update(user: address):
    assert msg.sender == self.owner, "Only owner can approve"
    assert self.companies[user].name != "", "Company not registered"
    self.update_approval[user] = True
    log UpdateApproved(user, block.timestamp)
