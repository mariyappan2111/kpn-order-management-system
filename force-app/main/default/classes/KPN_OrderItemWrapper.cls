public with sharing class KPN_OrderItemWrapper {

    public class PhoneNumber {
        public String countryCode;
        public String phnumber;
        public String extension;
    }

    public class Address {
        public String addressLine1;
        public String addressLine2;
        public String city;
        public String stateProvince;
        public String postalCode;
        public String country;
        public String deliveryInstructions;
    }

    public class Customer {
        public String customerId;
        public String firstName;
        public String lastName;
        public String email;
        public PhoneNumber phone;
        public PhoneNumber alternatePhone;
        public Date dateOfBirth;
        public String identificationType;
        public String identificationNumber;
    }

    public virtual class OrderItem {
        public String productId;
        public Integer quantity;
        public Map<String, Object> customizations;
    }

    public class OrderItemDetail extends OrderItem {
        public String productName;
        public Decimal unitPrice;
        public Decimal totalPrice;
    }

    public class PriceBreakdown {
        public Decimal subtotal;
        public Decimal setupFees;
        public Decimal taxes;
        public Decimal discounts;
        public Decimal shippingFee;
        public Decimal total;
    }

    public class Pagination {
        public Integer total;
        public Integer pglimit;
        public Integer offset;
    }

    public class OrderSummary {
        public String orderId;
        public String orderNumber;
        public String status;
        public String customerId;
        public String customerName;
        public Decimal totalAmount;
        public Datetime orderDate;
        public Date scheduledDeliveryDate;
    }

    public class CreateOrderRequest {
        public Customer customer;
        public List<OrderItem> orderItems;
        public Address deliveryAddress;
        public Address billingAddress;
        public Date preferredDeliveryDate;
        public String preferredTimeSlot;
        public Boolean installationRequired;
        public String notes;
    }

    public class OrderResponse {
        public String orderId;
        public String orderNumber;
        public String status;
        public Customer customer;
        public List<OrderItemDetail> orderItems;
        public Address deliveryAddress;
        public Address billingAddress;
        public Date scheduledDeliveryDate;
        public String deliveryTimeSlot;
        public Boolean installationScheduled;
        public Datetime installationDateTime;
        public Decimal totalAmount;
        public PriceBreakdown breakdown;
        public String trackingNumber;
        public Date estimatedActivationDate;
        public Datetime createdAt;
        public Datetime updatedAt;
    }

    public class OrderListResponse {
        public List<OrderSummary> orders;
        public Pagination pagination;
    }

    public class ErrorResponse {
        public String code;
        public String message;
        public List<ErrorDetail> details;
    }

    public class ErrorDetail {
        public String field;
        public String issue;
    }

    public static OrderListResponse parseListResponse(String jsonStr) {
        return (OrderListResponse) JSON.deserialize(jsonStr, OrderListResponse.class);
    }

    public static OrderResponse parseOrderResponse(String jsonStr) {
        return (OrderResponse) JSON.deserialize(jsonStr, OrderResponse.class);
    }

}