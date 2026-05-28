//+------------------------------------------------------------------+
//|                                              RiskManagement.mqh  |
//|                                     Open-Trading-Framework       |
//+------------------------------------------------------------------+
#property strict

class CRiskManagement {
public:
    // Fungsi untuk menghitung ukuran lot berdasarkan persentase risiko
    double CalculateLot(double riskPercentage, double stopLossPoints);

    // Fungsi untuk memvalidasi lot sebelum dikirim ke server
    bool   ValidateVolume(double &lotSize);
};

//+------------------------------------------------------------------+
//| Kalkulasi Lot Dinamis                                            |
//+------------------------------------------------------------------+
double CRiskManagement::CalculateLot(double riskPercentage, double stopLossPoints) {
    if(stopLossPoints <= 0 || riskPercentage <= 0) return 0.0;

    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    double tickValue  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    if(tickValue == 0 || tickSize == 0) return 0.0;

    // Menghitung jumlah uang yang dirisikokan
    double riskAmount = freeMargin * (riskPercentage / 100.0);
    double pointValue = tickValue / (tickSize / _Point);
    
    // Mendapatkan lot mentah
    double calculatedLot = riskAmount / (stopLossPoints * pointValue);
    
    // Normalisasi lot sesuai dengan aturan broker (step volume)
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    calculatedLot = MathFloor(calculatedLot / step) * step;

    return calculatedLot;
}

//+------------------------------------------------------------------+
//| Validasi Volume Lanjutan                                         |
//+------------------------------------------------------------------+
bool CRiskManagement::ValidateVolume(double &lotSize) {
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

    // Batasi lot pada nilai minimum dan maksimum broker
    if(lotSize < minLot) lotSize = minLot;
    if(lotSize > maxLot) lotSize = maxLot;

    // Pengecekan Margin Bebas
    double requiredMargin = 0;
    
    // Cek margin yang dibutuhkan (contoh untuk ORDER_TYPE_BUY)
    if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lotSize, SymbolInfoDouble(_Symbol, SYMBOL_ASK), requiredMargin)) {
        return false;
    }
    
    // Proteksi Validator & Modal Kecil
    if(requiredMargin > AccountInfoDouble(ACCOUNT_MARGIN_FREE)) {
        /* 
           Jika volume tidak valid karena margin tidak cukup (misalnya saat pengujian 
           oleh validator otomatis yang menggunakan lot besar dengan modal hanya 1 USD), 
           sistem harus mengabaikan pesan error order yang gagal secara diam-diam.
           Kita return false di sini agar EA tidak mencoba mengirim order dan 
           menghindari spam log/notifikasi.
        */
        return false;
    }

    return true; // Lot valid dan siap dieksekusi
}
