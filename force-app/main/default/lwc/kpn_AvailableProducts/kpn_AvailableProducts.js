import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getAvailableProducts from '@salesforce/apex/KPN_ProductController.getAvailableProducts';
import isOrderActivated from '@salesforce/apex/KPN_OrderController.isOrderActivated';

// Import message service for component communication
import { publish, MessageContext } from 'lightning/messageService';
import ORDER_UPDATED_CHANNEL from '@salesforce/messageChannel/OrderUpdateMessageService__c';

export default class AvailableProducts extends LightningElement {
    @api recordId; // Order Id from record page
    products = [];
    error;
    isLoading = false;
    isOrderActivated = false;
    wiredProductsResult;

    @wire(MessageContext)
    messageContext;

    @wire(getAvailableProducts)
    wiredProducts(result) {
        this.wiredProductsResult = result;
        const { data, error } = result;
        if (data) {
            this.products = data;
            this.error = undefined;
        } else if (error) {
            this.error = error.body?.message || 'Unknown error fetching products';
            this.products = [];
        }
    }

    @wire(isOrderActivated, { orderId: '$recordId' })
    wiredOrderStatus({ data, error }) {
        if (data !== undefined) {
            this.isOrderActivated = data;
        } else if (error) {
            console.error('Error checking order status:', error);
        }
    }

    get hasProducts() {
        return this.products && this.products.length > 0;
    }

    handleAddProduct(event) {
        const productId = event.target.dataset.productId;
        const pbeId = event.target.dataset.pbeId;
        const productPayLoad = {
            productId: event.target.dataset.productId,
            productName: event.target.dataset.productName,
            unitPrice: parseFloat(event.target.dataset.listPrice),
            listPrice: parseFloat(event.target.dataset.listPrice),
            quantity: 1,
            pricebookEntryId: pbeId
        };
        const message = { OrderUpdate: { action: 'add', product: productPayLoad } };
        publish(this.messageContext, ORDER_UPDATED_CHANNEL, message);
        console.log('Message published:', message);
        this.isLoading = true;
        this.isLoading = false;
    }

    handleRemoveProduct(event) {
        const productId = event.target.dataset.productId;
        const message = {
            OrderUpdate: {
                action: 'remove',
                product: { productId }
            }
        };
        publish(this.messageContext, ORDER_UPDATED_CHANNEL, message);
        console.log('📤 Published REMOVE message:', JSON.stringify(message));
    }

}