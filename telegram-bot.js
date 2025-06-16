// PDF Master Telegram Bot 整合
const TelegramBot = {
    // Bot 配置
    config: {
        botToken: '',
        adminIds: [], // 從環境變數載入
        webhookUrl: 'https://vectorized.cc/api/telegram/webhook',
        commands: {
            '/start': '顯示主選單',
            '/news': '查看新聞',
            '/add_news': '新增新聞',
            '/delete_news': '刪除新聞',
            '/ads': '查看廣告',
            '/add_ad': '新增廣告',
            '/delete_ad': '刪除廣告',
            '/status': '系統狀態',
            '/help': '幫助'
        }
    },
    
    // 鍵盤配置
    keyboards: {
        main: {
            keyboard: [
                ['📰 新聞管理', '📢 廣告管理'],
                ['📊 系統狀態', '👥 在線人數'],
                ['⚙️ 設定', '❓ 幫助']
            ],
            resize_keyboard: true,
            persistent: true
        },
        news: {
            keyboard: [
                ['📰 查看新聞', '➕ 新增新聞'],
                ['✏️ 編輯新聞', '🗑️ 刪除新聞'],
                ['🔙 返回主選單']
            ],
            resize_keyboard: true
        },
        ads: {
            keyboard: [
                ['📢 查看廣告', '➕ 新增廣告'],
                ['✏️ 編輯廣告', '🗑️ 刪除廣告'],
                ['🔄 切換廣告狀態'],
                ['🔙 返回主選單']
            ],
            resize_keyboard: true
        },
        cancel: {
            keyboard: [['❌ 取消']],
            resize_keyboard: true
        }
    },

    // 初始化 Bot
    init: async function() {
        try {
            const setWebhookUrl = `https://api.telegram.org/bot${this.config.botToken}/setWebhook`;
            const webhookData = {
                url: this.config.webhookUrl,
                allowed_updates: ['message', 'callback_query']
            };

            const response = await fetch(setWebhookUrl, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(webhookData)
            });

            const result = await response.json();
            console.log('Telegram Bot Webhook 設定結果:', result);
            return result.ok;
        } catch (error) {
            console.error('Telegram Bot 初始化失敗:', error);
            return false;
        }
    },

    // 測試 Bot 連接
    testConnection: async function() {
        try {
            const getMeUrl = `https://api.telegram.org/bot${this.config.botToken}/getMe`;
            const response = await fetch(getMeUrl);
            const result = await response.json();
            
            if (result.ok) {
                console.log('✅ Telegram Bot 連接成功！');
                console.log('Bot 資訊:', result.result);
                return true;
            } else {
                console.error('❌ Telegram Bot 連接失敗:', result);
                return false;
            }
        } catch (error) {
            console.error('❌ 測試連接時發生錯誤:', error);
            return false;
        }
    },

    // 發送訊息
    sendMessage: async function(chatId, text, options = {}) {
        const sendMessageUrl = `https://api.telegram.org/bot${this.config.botToken}/sendMessage`;
        const data = {
            chat_id: chatId,
            text: text,
            parse_mode: 'HTML',
            ...options
        };

        const response = await fetch(sendMessageUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });

        return await response.json();
    },

    // 廣播訊息給所有訂閱者
    broadcastMessage: async function(message) {
        const subscribers = JSON.parse(localStorage.getItem('tg_subscribers') || '[]');
        const results = [];
        
        // 模擬發送（實際應該從後端發送）
        for (const subscriber of subscribers) {
            results.push({ success: true, userId: subscriber.userId });
        }
        
        // 如果有設定頻道 ID，也發送到頻道
        if (this.config.chatId) {
            try {
                await this.sendMessage(this.config.chatId, message);
                results.push({ success: true, userId: 'channel' });
            } catch (error) {
                results.push({ success: false, userId: 'channel', error: error.message });
            }
        }
        
        return results;
    }
};

// 導出模組
if (typeof module !== 'undefined' && module.exports) {
    module.exports = TelegramBot;
} 