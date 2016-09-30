//
//  ViewController.swift
//  testPay
//
//  Created by Sanjay Maharjan on 9/16/16.
//  Copyright © 2016 Leapfrog Technology. All rights reserved.
//

import UIKit
import PassKit
import Stripe
import Alamofire


class ViewController: UIViewController {
    
    @IBOutlet var payButton: UIButton!
    
    //The array of the supported payment network(Network from which the service accepts the payment)
    let SupportedPaymentNetworks = [PKPaymentNetworkVisa]
    
    // Fill in your merchant ID here!
    let TestPayMerchantID = "merchant.com.leapfrog.testpay"
    
    //Set Your Stripe public key here //pk_test_....
    let StripePublicKey = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        //Determine if the payment can be done.
        //Here the button to make the payment is shown/hidden according to this ability
        //*1
        payButton.hidden = !PKPaymentAuthorizationViewController.canMakePaymentsUsingNetworks(SupportedPaymentNetworks)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func buyAction(sender: UIButton) {
        //Creating the Payment request object to collect info from the view controller
        //*2
        let request = PKPaymentRequest()
        //*2.1
        //Shipping address  
        request.requiredShippingAddressFields = PKAddressField.All
        
        //*2.2
        //merchant id
        request.merchantIdentifier = TestPayMerchantID
        //setting the accepting network
        request.supportedNetworks = SupportedPaymentNetworks
        request.merchantCapabilities = PKMerchantCapability.Capability3DS
        //country of request origin
        request.countryCode = "US"
        //currency to make payment in
        request.currencyCode = "USD"
//Also can be set for shipping method
//        request.shippingMethods = [PKShippingMethod.init(label: "Physical", amount: 0)]
        
        
        //*2.3
        //get the payment summary items to be shown in the view controller
        request.paymentSummaryItems = getPaymentSummaryItem()
        
        //*3
        //Authorization View Controller showing the request and listening to the finger print for authorization if the purchase
        let applePayController = PKPaymentAuthorizationViewController(paymentRequest: request)
        applePayController.delegate = self
        self.presentViewController(applePayController, animated: true, completion: nil)
        
    }
    
    func getPaymentSummaryItem() -> [PKPaymentSummaryItem] {
        //1+2+3
        //100-10+10
        return [
            PKPaymentSummaryItem(label: "SubTotal", amount: 100.0),
            PKPaymentSummaryItem(label: "Discount", amount: 10.0),//Sub Charges (subtotal, shipping cost...)
            PKPaymentSummaryItem(label: "Tax", amount: 10.0),
            PKPaymentSummaryItem(label: "Grand Total", amount: 100)//Last item always should be the grand total to be charged. But in services like UBER...
        ]

    }
    
    func createShippingAddressFromRef(address: ABRecord!) -> Address {
        var shippingAddress: Address = Address()
        
        shippingAddress.FirstName = ABRecordCopyValue(address, kABPersonFirstNameProperty)?.takeRetainedValue() as? String
        shippingAddress.LastName = ABRecordCopyValue(address, kABPersonLastNameProperty)?.takeRetainedValue() as? String
        
        let addressProperty : ABMultiValueRef = ABRecordCopyValue(address, kABPersonAddressProperty).takeUnretainedValue() as ABMultiValueRef
        if let dict : NSDictionary = ABMultiValueCopyValueAtIndex(addressProperty, 0).takeUnretainedValue() as? NSDictionary {
            shippingAddress.Street = dict[String(kABPersonAddressStreetKey)] as? String
            shippingAddress.City = dict[String(kABPersonAddressCityKey)] as? String
            shippingAddress.State = dict[String(kABPersonAddressStateKey)] as? String
            shippingAddress.Zip = dict[String(kABPersonAddressZIPKey)] as? String
        }
        
        return shippingAddress
    }
    
    
    

}

struct Address {
    var Street: String?
    var City: String?
    var State: String?
    var Zip: String?
    var FirstName: String?
    var LastName: String?
    
    init() {
    }
}

extension ViewController: PKPaymentAuthorizationViewControllerDelegate {
    //*4
    func paymentAuthorizationViewController(controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, completion: ((PKPaymentAuthorizationStatus) -> Void)) {
        
        
        
        let shippingAddress = self.createShippingAddressFromRef(payment.shippingAddress)
        
        
        //private key in the server (app server where the shiping details will be sent
        //public key here
        Stripe.setDefaultPublishableKey(StripePublicKey)
        
        
        STPAPIClient.sharedClient().createTokenWithPayment(payment) {
            (token, error) -> Void in
            
            if (error != nil) {
                print("error - \(error)")
                print("token - \(token)")
                completion(PKPaymentAuthorizationStatus.Failure)
                return
            }
            
            
            let shippingAddress = self.createShippingAddressFromRef(payment.shippingAddress)
            
            
            let url = "http://0.0.0.0:5000/pay"  // Replace with computers local IP Address!

            
            let body: [String: AnyObject] = ["stripeToken": token!.tokenId,
                        "amount": NSDecimalNumber(string: "100"),
                        "description": "Payment request from iphone simulator",
                        "shipping": [
                            "city": shippingAddress.City!,
                            "state": shippingAddress.State!,
                            "zip": shippingAddress.Zip!,
                            "firstName": shippingAddress.FirstName!,
                            "lastName": shippingAddress.LastName!]
            ]

            let headers = ["Content-Type":"text/html"/*"application/json"*/, "Accept":"application/json"]
            
            
            
            Alamofire.Manager.sharedInstance.request(.POST, url, parameters: body, encoding: .JSON, headers: headers).responseJSON(completionHandler: {
                    (response) in
                //*5
                    if response.result.error != nil {
                        print("failure")
                        completion(PKPaymentAuthorizationStatus.Failure)
                    } else {
                        print("success")
                        completion(PKPaymentAuthorizationStatus.Success)
                        
                    }
                })
        }
    }
    
    func paymentAuthorizationViewControllerDidFinish(controller: PKPaymentAuthorizationViewController) {
        controller.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func paymentAuthorizationViewController(controller: PKPaymentAuthorizationViewController, didSelectShippingAddress address: ABRecord, completion: (PKPaymentAuthorizationStatus, [PKShippingMethod], [PKPaymentSummaryItem]) -> Void) {
        let method = PKShippingMethod(label: "Delivery by Man", amount: 5)
        method.identifier = "Delivery by Man"
        method.detail = "this is the shiping method description"
        completion(PKPaymentAuthorizationStatus.Success, [method], getPaymentSummaryItem())
    }
    
}

