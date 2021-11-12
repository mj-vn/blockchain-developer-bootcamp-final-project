Decentralized P2P Marketplace
==================================

About
-----------
This project would be a peer-to-peer marketplace which people can offer 
and sell their goods to buyers.

Goods can be priced in Ether.

This is a full decentralized marketplace without censorship which the code is law 
and there will be some conditions to prevent fraud and the code will 
manage the payment and delivery flow with an escrow smart contract.

Rules
-------
* All the users should have a Metamask wallet.

* All the users should identify themselves with their ethereum address.

* Sellers should stake Ether equal to the value of their goods to prevent fraud such as 
offer a good which does not exist, the offered good has a problem, They will not deliver the good, etc 
and the staked value will refund after selling the good. 

* Buyers Should stake Ether equal to the value of the good they will buy to prevent fraud such 
as they will not confirm they got the good and the staked value will refund after the good 
is delivered to them.

* The seller should confirm that it agrees with the purchase then the purchase will be active.



Flows
---------
* When a user entered the site should connect its wallet to be identified.
* As Seller To Submit The Offer:
    1. The user if wants to offer a good, Should enter its email also the country or city and 
    let the application get its public key
    2. Then can select the category, add title, its description, and specification, and the price in Ether. 
    Also can add some pictures of the product. 
    3. Before submitting the product, the seller should stake Ether equal to the value of the price of the good.
    4. Finally the offer will be saved on the blockchain.
    
* As Buyer To Buy A Good:
    1. The Buyer should click on the buy button
    2. Enter the address and contact data
        - Before sending the data of this step to the blockchain they would be encrypted off-chain automatically 
        with seller public key to protect privacy matters.
    3. Buyer will deposit Ether equal to the value of the price for the purchase
        of the good that will be escrowed until the product will be delivered.
    4. Buyer should stake Ether equal to the value of the price 
        of good, after the good delivered the amount will refunded.
    
    5. Finally we will save the order to the blockchain.
    
* After the order is submitted:
    1. Seller will decide to approve or reject the order.
        - If the seller rejects the order, the deposited amount paid for the purchase of the good will refund to the 
        buyer.
         Also, the staked Ether will refund to the buyer
        - If the seller approves the order, the order will be confirmed and they will contact themselves to 
        coordinate the delivery of the good. \
        The seller should deliver the good within the next thirty days. If it did not, the order is failed and all 
        the assets will refund.

* Deliver The Good:
    1. Seller must notify the dapp when posted the good or delivered it with other ways.
    2. Buyer Must confirm that it has received the goods. 
    3. The Ether that has been escrowed, will pay to the seller.
    4. The Staked amount of Ether from the buyer and seller will refund.

