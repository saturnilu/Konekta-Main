export const subscriptionService = {
  async getActivePlans() {
    return [] as unknown[];
  },
  async getUserPlan(_userId: number) {
    return null;
  },
  async createInvoice(_userId: number, _planId: number) {
    throw new Error('Subscription checkout not yet implemented');
  },
  async verifyInvoicePayment(_invoiceId: number) {
    throw new Error('Payment verification not yet implemented');
  },
  async cancelSubscription(_invoiceId: number) {
    throw new Error('Subscription cancellation not yet implemented');
  },
};
