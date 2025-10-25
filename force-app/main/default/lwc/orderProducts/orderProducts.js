import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOrderItems from '@salesforce/apex/KPN_OrderController.getOrderItems';
import activateOrder from '@salesforce/apex/KPN_OrderController.activateOrder';
import isOrderActivated from '@salesforce/apex/KPN_OrderController.isOrderActivated';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import ORDER_UPDATED_CHANNEL from '@salesforce/messageChannel/OrderUpdateMessageService__c';

const COLUMNS = [
    { label: 'Product Name', fieldName: 'productName', type: 'text' },
    { label: 'Unit Price', fieldName: 'unitPrice', type: 'currency', typeAttributes: { currencyCode: 'EUR' } },
    { label: 'Quantity', fieldName: 'quantity', type: 'number' },
    { label: 'Total Price', fieldName: 'totalPrice', type: 'currency', typeAttributes: { currencyCode: 'EUR' } }
];

export default class OrderProducts extends LightningElement {
    @api recordId; // Order Id
    orderItems = [];
    columns = COLUMNS;
    error;
    isLoading = false;
    isOrderActivated = false;
    subscription = null;
    wiredOrderItemsResult;

    @wire(MessageContext)
    messageContext;

    // Subscribe to message channel when component connects
    connectedCallback() {
        this.fetchOrderItems();
        //this.subscribeToMessageChannel();
    }

    renderedCallback() {
        if (!this.subscription && this.messageContext) {
            this.subscription = subscribe(
                this.messageContext,
                ORDER_UPDATED_CHANNEL,
                (message) => this.handleOrderUpdate(message)
            );
        }
    }

    // Unsubscribe when component disconnects
    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
    }

    fetchOrderItems() {
        this.isLoading = true;
        getOrderItems({ orderId: this.recordId })
            .then(data => {
                this.orderItems = data;
                this.error = undefined;
            })
            .catch(error => {
                this.orderItems = [];
                this.error = error.body?.message || 'Unknown error fetching order items';
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Wire to check if order is activated
    @wire(isOrderActivated, { orderId: '$recordId' })
    wiredOrderStatus({ data, error }) {
        if (data !== undefined) {
            this.isOrderActivated = data;
        } else if (error) {
            console.error('Error checking order status:', error);
        }
    }

    get hasOrderItems() {
        return this.orderItems && this.orderItems.length > 0;
    }

    get totalAmount() {
        return this.orderItems.reduce((sum, item) => sum + (item.totalPrice || 0), 0);
    }

    get isActivateDisabled() {
        return this.isOrderActivated || !this.hasOrderItems || this.isLoading;
    }

    // Subscribe to order updates
    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                ORDER_UPDATED_CHANNEL,
                (message) => this.handleOrderUpdate(message)
            );
        }
    }

    // Unsubscribe from message channel
    unsubscribeToMessageChannel() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    handleOrderUpdate(message) {
        if (!message?.OrderUpdate) return;

        const { action, product } = message.OrderUpdate;
        let updatedItems = [...this.orderItems];
        if (action === 'add') {
            const existing = updatedItems.find(p => p.productId === product.productId); // Check if product already exists
            if (existing) {
                existing.quantity += 1;
                existing.totalPrice = existing.unitPrice * existing.quantity;
            } else {
                updatedItems.push({ ...product, totalPrice: product.unitPrice * product.quantity });
            }
        } else if (action === 'remove') {
            const existing = updatedItems.find(p => p.productId === product.productId);
            if (existing) {
                if (existing.quantity > 1) {
                    existing.quantity -= 1;
                    existing.totalPrice = existing.unitPrice * existing.quantity;
                } else {
                    updatedItems = updatedItems.filter(p => p.productId !== product.productId);
                }
            }
        }
        this.orderItems = [...updatedItems];
        console.log('Updated Items: ' + JSON.stringify(this.orderItems));
    }

    // Handle order activation
    handleActivateOrder() {
        console.log('Order Items: ' + JSON.stringify(this.orderItems));
        this.isLoading = true;
        activateOrder({ orderId: this.recordId, selectedProducts: this.orderItems })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Order has been activated',
                        variant: 'success'
                    })
                );
                this.fetchOrderItems();
                this.isOrderActivated = true;
            }).catch((error) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error activating order',
                        message: error.body?.message || 'Unknown error',
                        variant: 'error'
                    })
                );
            }).finally(() => {
                this.isLoading = false;
                eval("$A.get('e.force:refreshView').fire();");
            });
    }
}
