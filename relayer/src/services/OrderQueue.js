class OrderQueue {
  constructor() {
    this.orders = new Map();
    this.orderQueue = [];
    this.nextOrderId = 1;
  }
  
  async addOrder(order) {
    const orderId = `order_${Date.now()}_${this.nextOrderId++}`;
    const orderData = {
      id: orderId,
      ...order,
      timestamp: Date.now(),
      status: 'pending'
    };
    
    this.orders.set(orderId, orderData);
    this.orderQueue.push(orderId);
    
    return orderId;
  }
  
  async getOrder(orderId) {
    return this.orders.get(orderId);
  }
  
  async getNextBatch(maxSize) {
    const batch = [];
    const now = Date.now();
    
    // Get up to maxSize orders that are still valid
    while (batch.length < maxSize && this.orderQueue.length > 0) {
      const orderId = this.orderQueue[0];
      const order = this.orders.get(orderId);
      
      if (!order) {
        this.orderQueue.shift();
        continue;
      }
      
      // Check if order is still valid
      if (order.deadline && order.deadline * 1000 < now) {
        this.orderQueue.shift();
        order.status = 'expired';
        continue;
      }
      
      batch.push(order);
      this.orderQueue.shift();
    }
    
    return batch;
  }
  
  async clearBatch(orders) {
    for (const order of orders) {
      const storedOrder = this.orders.get(order.id);
      if (storedOrder) {
        storedOrder.status = 'executed';
      }
    }
  }
  
  size() {
    return this.orderQueue.length;
  }
}

module.exports = OrderQueue;