# **Templates**

This subfolder contains two templates designed for algorithmic trading strategies in the MQL5 language. Each template serves a specific purpose in trading automation.

## **Single_Trade.mq5**

The **`Single_Trade.mq5`** template is tailored for strategies that execute only a single trade at a time. Its design prioritizes speed and simplicity, making it well-suited for optimization. Key characteristics of this template include:

- **Optimization Efficiency:** Built with a focus on speed, avoiding unnecessary loops and complexity to facilitate faster optimization.
- **Straightforward Logic:** The template employs a clear and direct logic, primarily checking the status of the last trade opened without introducing unnecessary complications.
- **No Pyramiding Support:** The template is not designed to support pyramiding, ensuring it remains dedicated to strategies that involve only a single trade at any given time.

## **Multi_Trade.mq5**

The **`Multi_Trade.mq5`** template offers a more generic approach, suitable for strategies that involve multiple trades. While this template provides greater flexibility, it comes with certain trade-offs, including:

- **Optimization Flexibility:** The template checks various conditions on every tick or candle, allowing for a more versatile strategy. However, this can lead to slower optimization due to increased complexity.
- **Pyramiding Support:** Unlike the **`Single_Trade.mq5`** template, this template is designed to support pyramiding, allowing for the addition of new positions during the course of the strategy.

This templates will be periodically extended, adding common features that trading systems may have.