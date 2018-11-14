//
//  RNUnifiedContacts.swift
//  RNUnifiedContacts
//
//  Copyright © 2016 Joshua Pinter. All rights reserved.
//

import Contacts
import ContactsUI
import Foundation

@available(iOS 9.0, *)
@objc(RNUnifiedContacts)
class RNUnifiedContacts: NSObject {

    //  iOS Reference: https://developer.apple.com/library/ios/documentation/Contacts/Reference/CNContact_Class/#//apple_ref/doc/constant_group/Metadata_Keys

    let keysToFetch = [
        CNContactDepartmentNameKey,
        CNContactEmailAddressesKey,
        CNContactFamilyNameKey,
        CNContactGivenNameKey,
        CNContactIdentifierKey,
        CNContactImageDataAvailableKey,
        CNContactJobTitleKey,
        CNContactMiddleNameKey,
        CNContactNamePrefixKey,
        CNContactNameSuffixKey,
        CNContactNicknameKey,
        CNContactOrganizationNameKey,
        CNContactPhoneNumbersKey,
        CNContactThumbnailImageDataKey,
        CNContactTypeKey,
        ]


    @objc func userCanAccessContacts(_ callback: (Array<Bool>) -> ()) -> Void {
        let authorizationStatus = CNContactStore.authorizationStatus(for: CNEntityType.contacts)

        switch authorizationStatus{
        case .notDetermined, .restricted, .denied:
            callback([false])

        case .authorized:
            callback([true])
        }
    }

    @objc func requestAccessToContacts(_ callback: @escaping (Array<Bool>) -> ()) -> Void {
        userCanAccessContacts() { (userCanAccessContacts) in
            if (userCanAccessContacts == [true]) {
                callback([true])
                return
            }

            CNContactStore().requestAccess(for: CNEntityType.contacts) { (userCanAccessContacts, error) in
                if (userCanAccessContacts) {
                    callback([true])
                    return
                } else {
                    callback([false])
                    return
                }
            }
        }
    }

    @objc func alreadyRequestedAccessToContacts(_ callback: (Array<Bool>) -> ()) -> Void {
        let authorizationStatus = CNContactStore.authorizationStatus(for: CNEntityType.contacts)

        switch authorizationStatus{
        case .notDetermined:
            callback([false])

        case .authorized, .restricted, .denied:
            callback([true])
        }
    }

    @objc func getContact(_ identifier: String, callback: (NSArray) -> () ) -> Void {
        let cNContact = getCNContact( identifier, keysToFetch: keysToFetch as [CNKeyDescriptor] )
        if ( cNContact == nil ) {
            callback( ["Could not find a contact with the identifier ".appending(identifier), NSNull()] )
            return
        }

        let contactAsDictionary = convertCNContactToDictionary( cNContact! )
        callback( [NSNull(), contactAsDictionary] )
    }

    // Pseudo overloads getContacts but with no searchText.
    // Makes it easy to get all the Contacts with not passing anything.
    // NOTE: I tried calling the two methods the same but it barfed. It should be
    //   allowed but perhaps how React Native is handling it, it won't work. PR
    //   possibility.
    //
    @objc func getContacts(_ callback: (NSObject) -> ()) -> Void {
        searchContacts(nil) { (result: NSObject) in
            callback(result)
        }
    }


    @objc func searchContacts(_ searchText: String?, callback: (NSArray) -> ()) -> Void {
        let contactStore = CNContactStore()
        do {
            var cNContacts = [CNContact]()

            let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch as [CNKeyDescriptor])

            fetchRequest.sortOrder = CNContactSortOrder.givenName

            try contactStore.enumerateContacts(with: fetchRequest) { (cNContact, pointer) -> Void in
                if searchText == nil {
                    // Add all Contacts if no searchText is provided.
                    cNContacts.append(cNContact)
                } else {
                    // If the Contact contains the search string then add it.
                    if self.contactContainsText( cNContact, searchText: searchText! ) {
                        cNContacts.append(cNContact)
                    }
                }
            }

            var contacts = [NSDictionary]();
            for cNContact in cNContacts {
                contacts.append( convertCNContactToDictionary(cNContact) )
            }

            callback([NSNull(), contacts])
        } catch let error as NSError {
            NSLog("Problem getting contacts.")
            NSLog(error.localizedDescription)

            callback([error.localizedDescription, NSNull()])
        }
    }

    /////////////
    // PRIVATE //

    func getCNContact( _ identifier: String, keysToFetch: [CNKeyDescriptor] ) -> CNContact? {
      let contactStore = CNContactStore()
      do {
        let cNContact = try contactStore.unifiedContact( withIdentifier: identifier, keysToFetch: keysToFetch )
        return cNContact
      } catch let error as NSError {
        NSLog("Problem getting unified contact with identifier: " + identifier)
        NSLog(error.localizedDescription)
        return nil
      }
    }

    func contactContainsText( _ cNContact: CNContact, searchText: String ) -> Bool {
        let searchText   = searchText.lowercased();
        let textToSearch = cNContact.givenName.lowercased() + " " + cNContact.familyName.lowercased() + " " + cNContact.nickname.lowercased()

        if searchText.isEmpty || textToSearch.contains(searchText) {
            return true
        } else {
            return false
        }
    }

    func getLabeledDict<T>(_ item: CNLabeledValue<T>) -> [String: Any] {
        var dict = [String: Any]()
        dict["identifier"] = item.identifier
        if let label = item.label {
            if label.hasPrefix("_$!<") && label.hasSuffix(">!$_") {
                addString(&dict, key: "label", value: label.substring(with: label.index(label.startIndex, offsetBy: 4)..<label.index(label.endIndex, offsetBy: -4)))
            } else {
                addString(&dict, key: "label", value: item.label)
            }
        }
        addString(&dict, key: "localizedLabel", value: item.label == nil ? nil : CNLabeledValue<T>.localizedString(forLabel: item.label!))
        return dict
    }

    func addString(_ dict: inout [String: Any], key: String, value: String?) {
        if let value = value, !value.isEmpty {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if (!trimmed.isEmpty) {
                dict[key] = value
            }
        }
    }

    func convertCNContactToDictionary(_ cNContact: CNContact) -> NSDictionary {
        var contact = [String: Any]()

        addString(&contact, key: "departmentName", value: cNContact.departmentName)

        if cNContact.emailAddresses.count > 0 {
            contact["emailAddresses"] = cNContact.emailAddresses.map { (item) -> [String: Any] in
                var dict = getLabeledDict(item)
                addString(&dict, key: "value", value: item.value as String)
                return dict
            }
        }

        addString(&contact, key: "familyName", value: cNContact.familyName)
        addString(&contact, key: "givenName", value: cNContact.givenName)
        addString(&contact, key: "identifier", value: cNContact.identifier)

        contact["imageDataAvailable"] = cNContact.imageDataAvailable

        addString(&contact, key: "jobTitle", value: cNContact.jobTitle)
        addString(&contact, key: "middleName", value: cNContact.middleName)
        addString(&contact, key: "namePrefix", value: cNContact.namePrefix)
        addString(&contact, key: "nameSuffix", value: cNContact.nameSuffix)
        addString(&contact, key: "nickname", value: cNContact.nickname)

        addString(&contact, key: "organizationName", value: cNContact.organizationName)

        if cNContact.phoneNumbers.count > 0 {
            contact["phoneNumbers"] = cNContact.phoneNumbers.map { (item) -> [String: Any] in
                var dict = getLabeledDict(item)
                addString(&dict, key: "stringValue", value: item.value.stringValue)
                addString(&dict, key: "countryCode", value: item.value.value(forKey: "countryCode") as? String)
                addString(&dict, key: "digits", value: item.value.value(forKey: "digits") as? String)
                return dict
            }
        }

        if let thumbnailImageData = cNContact.thumbnailImageData {
            addString(&contact, key: "thumbnailImageData", value: thumbnailImageData.base64EncodedString(options: []))
        }

        addString(&contact, key: "fullName", value: CNContactFormatter.string( from: cNContact, style: .fullName ))

        return contact as NSDictionary
    }

    func convertPhoneNumberToCNLabeledValue(_ phoneNumber: NSDictionary) -> CNLabeledValue<CNPhoneNumber> {
        var formattedLabel = String()
        let userProvidedLabel = phoneNumber["label"] as! String
        let lowercaseUserProvidedLabel = userProvidedLabel.lowercased()
        switch (lowercaseUserProvidedLabel) {
        case "home":
            formattedLabel = CNLabelHome
        case "work":
            formattedLabel = CNLabelWork
        case "mobile":
            formattedLabel = CNLabelPhoneNumberMobile
        case "iphone":
            formattedLabel = CNLabelPhoneNumberiPhone
        case "main":
            formattedLabel = CNLabelPhoneNumberMain
        case "home fax":
            formattedLabel = CNLabelPhoneNumberHomeFax
        case "work fax":
            formattedLabel = CNLabelPhoneNumberWorkFax
        case "pager":
            formattedLabel = CNLabelPhoneNumberPager
        case "other":
            formattedLabel = CNLabelOther
        default:
            formattedLabel = userProvidedLabel
        }

        return CNLabeledValue(
            label:formattedLabel,
            value:CNPhoneNumber(stringValue: phoneNumber["stringValue"] as! String)
        )
    }

    func convertEmailAddressToCNLabeledValue(_ emailAddress: NSDictionary) -> CNLabeledValue<NSString> {
        var formattedLabel = String()
        let userProvidedLabel = emailAddress["label"] as! String
        let lowercaseUserProvidedLabel = userProvidedLabel.lowercased()
        switch (lowercaseUserProvidedLabel) {
        case "home":
            formattedLabel = CNLabelHome
        case "work":
            formattedLabel = CNLabelWork
        case "icloud":
            formattedLabel = CNLabelEmailiCloud
        case "other":
            formattedLabel = CNLabelOther
        default:
            formattedLabel = userProvidedLabel
        }

        return CNLabeledValue(
            label:formattedLabel,
            value: emailAddress["value"] as! NSString
        )
    }
}
