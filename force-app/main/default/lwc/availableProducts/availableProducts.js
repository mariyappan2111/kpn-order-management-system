import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getAvailableProducts from '@salesforce/apex/KPN_ProductController.getAvailableProducts';
import isOrderActivated from '@salesforce/apex/KPN_OrderController.isOrderActivated';
import { publish, MessageContext } from 'lightning/messageService';
import ORDER_UPDATED_CHANNEL from '@salesforce/messageChannel/OrderUpdateMessageService__c';

export default class AvailableProducts extends LightningElement {
    @api recordId; // Order Id from record page

    // Product data
    @track allProducts = [];
    @track filteredProducts = [];
    @track displayedProducts = [];
    error;
    isLoading = false;
    isLoadingMore = false;
    isOrderActivated = false;
    wiredProductsResult;

    // Pagination
    @track currentPage = 1;
    @track pageSize = 12;
    @track totalPages = 1;

    // Search and Filter
    @track searchKey = '';
    @track selectedCategory = '';
    @track selectedFilter = 'all';

    // Infinite scroll
    scrollThreshold = 0.8;

    @wire(MessageContext)
    messageContext;

    @wire(getAvailableProducts)
    wiredProducts(result) {
        this.wiredProductsResult = result;
        const { data, error } = result;

        if (data) {
            this.allProducts = data.map(product => ({
                ...product,
                iconName: this.getProductIcon(product.category),
                category: product.category || 'Uncategorized',
                description: product.description || this.getDefaultDescription(product.category)
            }));
            console.log('Fetched products:', this.allProducts);
            this.error = undefined;
            this.applyFilters();
        } else if (error) {
            this.error = error.body?.message || 'Unknown error fetching products';
            this.allProducts = [];
            this.filteredProducts = [];
            this.displayedProducts = [];
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

    // Computed properties
    get hasProducts() {
        return this.displayedProducts && this.displayedProducts.length > 0;
    }

    get productCountLabel() {
        return `${this.totalRecords} Products`;
    }

    get totalRecords() {
        return this.filteredProducts.length;
    }

    get startRecord() {
        return this.totalRecords === 0 ? 0 : (this.currentPage - 1) * this.pageSize + 1;
    }

    get endRecord() {
        const end = this.currentPage * this.pageSize;
        return end > this.totalRecords ? this.totalRecords : end;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages;
    }

    // category options for filter dropdown from available product API
    get categoryOptions() {
        const categories = [...new Set(this.allProducts.map(p => p.category).filter(c => c))];
        return [
            { label: 'All Categories', value: '' },
            ...categories.map(ct => ({ label: ct, value: ct }))
        ];
    }

    get filterOptions() {
        return [
            { label: 'All Products', value: 'all' },
            { label: 'Salesforce Products', value: 'salesforceProducts' },
            { label: 'API Products', value: 'apiProducts' },
            { label: 'In Order', value: 'inOrder' },
            { label: 'Not in Order', value: 'notInOrder' }
        ];
    }

    get pageSizeOptions() {
        return [
            { label: '12 per page', value: '12' },
            { label: '24 per page', value: '24' },
            { label: '48 per page', value: '48' },
            { label: '96 per page', value: '96' }
        ];
    }

    // Event Handlers
    handleSearch(event) {
        this.searchKey = event.target.value.toLowerCase();
        this.currentPage = 1;
        this.applyFilters();
    }

    handleCategoryChange(event) {
        this.selectedCategory = event.detail.value;
        this.currentPage = 1;
        this.applyFilters();
    }

    handleFilterChange(event) {
        this.selectedFilter = event.detail.value;
        this.currentPage = 1;
        this.applyFilters();
    }

    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.detail.value, 10);
        this.currentPage = 1;
        this.updateDisplayedProducts();
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updateDisplayedProducts();
            this.scrollToTop();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updateDisplayedProducts();
            this.scrollToTop();
        }
    }

    handleScroll(event) {
        const element = event.target;
        const scrollPercentage = (element.scrollTop + element.clientHeight) / element.scrollHeight;

        // Load more when scrolled past threshold
        if (scrollPercentage > this.scrollThreshold && !this.isLoadingMore && !this.isLastPage) {
            this.loadMoreProducts();
        }
    }

    handleAddProduct(event) {
        const productPayload = {
            productId: event.target.dataset.productId,
            productName: event.target.dataset.productName,
            unitPrice: parseFloat(event.target.dataset.listPrice),
            listPrice: parseFloat(event.target.dataset.listPrice),
            category: event.target.dataset.category,
            quantity: 1,
            pricebookEntryId: event.target.dataset.pricebookEntryId
        };

        const message = {
            OrderUpdate: {
                action: 'add',
                product: productPayload
            }
        };

        publish(this.messageContext, ORDER_UPDATED_CHANNEL, message);

        this.showToast('Success', `${productPayload.productName} added to order`, 'success');

        // Refresh product list to update "In Order" status
        this.refreshProducts();
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

        this.showToast('Success', 'Product removed from order', 'success');

        // Refresh product list
        this.refreshProducts();
    }

    // Helper Methods
    applyFilters() {
        let filtered = [...this.allProducts];

        if (this.searchKey) {
            filtered = filtered.filter(product =>
                product.productName.toLowerCase().includes(this.searchKey)
            );
        }

        if (this.selectedCategory) {
            filtered = filtered.filter(product =>
                product.category === this.selectedCategory
            );
        }
        if (this.selectedFilter === 'salesforceProducts') {
            filtered = filtered.filter(product =>
                product.productId && product.productId.startsWith('01t')
            );
        } else if (this.selectedFilter === 'apiProducts') {
            filtered = filtered.filter(product =>
                !product.productId || !product.productId.startsWith('01t')
            );
        }

        if (this.selectedFilter === 'inOrder') {
            filtered = filtered.filter(product => product.isInOrder);
        } else if (this.selectedFilter === 'notInOrder') {
            filtered = filtered.filter(product => !product.isInOrder);
        }

        this.filteredProducts = filtered;
        this.totalPages = Math.ceil(this.filteredProducts.length / this.pageSize);
        this.updateDisplayedProducts();
    }

    updateDisplayedProducts() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.displayedProducts = this.filteredProducts.slice(start, end);
    }

    loadMoreProducts() {
        if (this.isLastPage) return;

        this.isLoadingMore = true;

        setTimeout(() => {
            this.currentPage++;
            this.updateDisplayedProducts();
            this.isLoadingMore = false;
        }, 300);
    }

    scrollToTop() {
        const grid = this.template.querySelector('.product-grid');
        if (grid) {
            grid.scrollTop = 0;
        }
    }

    refreshProducts() {
        this.isLoading = true;
        refreshApex(this.wiredProductsResult)
            .then(() => {
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error refreshing products:', error);
            });
    }

    getProductIcon(category) {
        const iconMap = {
            'Mobile': 'standard:call',
            'Broadband': 'standard:network_contract',
            'TV': 'standard:live_chat',
            'Equipment': 'standard:asset_object',
            'Add-on': 'standard:service_contract',
            'Bundle': 'standard:product_item'
        };
        return iconMap[category] || 'standard:product';
    }

    getDefaultDescription(category) {
        const descMap = {
            'Mobile': 'Stay connected with our mobile plans',
            'Broadband': 'High-speed internet for your home',
            'TV': 'Entertainment packages for the whole family',
            'Equipment': 'Premium devices and accessories',
            'Add-on': 'Enhance your subscription',
            'Bundle': 'Complete package solution'
        };
        return descMap[category] || 'Quality telecom service';
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
} 