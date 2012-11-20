package com.example.android;

import android.content.Context;
import android.os.Bundle;
import android.util.AttributeSet;
import android.widget.RelativeLayout;
import android.widget.ScrollView;
import android.widget.SlidingDrawer;
import android.widget.TextView;

import com.moodstocks.android.MoodstocksError;
import com.moodstocks.android.Result;
import com.moodstocks.android.Scanner;
import com.moodstocks.android.ScannerSession;
import com.moodstocks.android.Sync;

public class Overlay extends RelativeLayout
implements ScanActivity.Listener, SlidingDrawer.OnDrawerCloseListener,
					 SlidingDrawer.OnDrawerOpenListener, Sync.Listener {

	public static final String TAG = "Overlay";
	private String ean_info = "";
	private String qr_info = "";
	private String cache_info = "";
	private String dmtx_info = "";
	private SlidingDrawer drawer = null;
	private ScannerSession session = null;
	private Scanner scanner = null;

	public Overlay(Context context, AttributeSet attrs) {
		super(context, attrs);
		try {
			scanner = Scanner.get();
		} catch (MoodstocksError e) {
			e.log();
		}
	}

	public void init() {
		this.drawer = ((SlidingDrawer) findViewById(R.id.drawer));
		this.drawer.setOnDrawerCloseListener(this);
		this.drawer.setOnDrawerOpenListener(this);
		((ScrollView) findViewById(R.id.scroll)).setSmoothScrollingEnabled(true);
		allInfoVisible(true);
		/* We want to update UI when a sync is running, so we add 
		 * the overlay as an extra sync listener:
		 */
		scanner.addExtraSyncListener(this);
	}
	
	// update information about EANs
	private void eanInfo(boolean ean8, boolean ean13) {
		TextView tv = (TextView) findViewById(R.id.ean_info);
		String s;
		if (ean8 || ean13) {
			s = "[X] EAN";
		}
		else s = "[ ] EAN";
		if (ean8 || ean13) {
			if (ean8 && ean13) {
				s += " (8,13)";
			}
			else {
				if (ean8) s += " (8)";
				else s += " (13)";
			}
		}
		if (!s.equals(ean_info)) {
			tv.setText(s);
			ean_info = new String(s);
		}
	}
	
	//update information about QR Codes.
	private void qrInfo(boolean qr) {
		TextView tv = (TextView) findViewById(R.id.qrcode_info);
		String s;
		if (qr) {
			s = "[X] QR Code";
		}
		else {
			s = "[ ] QR Code";
		}
		if (!s.equals(qr_info)) {
			tv.setText(s);
			qr_info = new String(s);
		}
	}

	//update information about Datamatrix.
	private void dmtxInfo(boolean dmtx) {
		TextView tv = (TextView) findViewById(R.id.dmtx_info);
		String s;
		if (dmtx) {
			s = "[X] Datamatrix";
		}
		else {
			s = "[ ] Datamatrix";
		}
		if (!s.equals(dmtx_info)) {
			tv.setText(s);
			dmtx_info = new String(s);
		}
	}

	/* Update information about offline cache.
	 * It will display the number of images currently in cache if no sync
	 * is currently running, otherwise it will display "syncing..." without
	 * further information on the sync progression, until it is made available
	 * by a call to cacheInfo(int total, int current).
	 */
	private void cacheInfo() {
		TextView tv = (TextView) findViewById(R.id.cache_info);
		String s;
		if (scanner.isSyncing()) {
			s = "[X] Cache (Syncing...)";
		}
		else {
			int nb = 0;
			try {
				nb = scanner.count();
			} catch (MoodstocksError e) {
				// fail silently
			}
			s = "[X] Cache ("+nb+" images)";
		}
		if (!s.equals(cache_info)) {
			tv.setText(s);
			cache_info = new String(s);
		}
	}
	
	// Update the sync progression
	private void cacheInfo(int total, int current) {
		TextView tv = (TextView) findViewById(R.id.cache_info);
		int p = (current*100)/total;
		String s;
		if (p < 100)
			s = "[X] Cache (Syncing... "+p+"%)";
		else
			s = "[X] Cache (Updating...)";
		if (!s.equals(cache_info)) {
			tv.setText(s);
			cache_info = new String(s);
		}
	}
	
	private void displayResult(String result) {
		TextView res = (TextView) findViewById(R.id.result);
		res.setText(result);
		if (drawer.getVisibility() != VISIBLE) {
			drawer.setVisibility(VISIBLE);
		}
		if (!drawer.isOpened()) {
			drawer.animateOpen();
		}
	}

	private void allInfoVisible(boolean b) {
		int v = b ? VISIBLE : INVISIBLE;
		((TextView) findViewById(R.id.info1)).setVisibility(v);
		((TextView) findViewById(R.id.info2)).setVisibility(v);
		((TextView) findViewById(R.id.info3)).setVisibility(v);
		((TextView) findViewById(R.id.ean_info)).setVisibility(v);
		((TextView) findViewById(R.id.qrcode_info)).setVisibility(v);
		((TextView) findViewById(R.id.cache_info)).setVisibility(v);
		((TextView) findViewById(R.id.dmtx_info)).setVisibility(v);
		v = b ? INVISIBLE : VISIBLE;
		drawer.setVisibility(v);
	}


	//-----------------------
	// ScanActivity.Listener
	//-----------------------
	@Override
	public void onStatusUpdate(Bundle status) {

		// update EAN info
		if (status.containsKey("decode_ean_8") && status.containsKey("decode_ean_13"))
			eanInfo(status.getBoolean("decode_ean_8"), status.getBoolean("decode_ean_13"));

		// update QR codes info
		if (status.containsKey("decode_qrcode"))
			qrInfo(status.getBoolean("decode_qrcode"));

		// update Datamatrix info
		if (status.containsKey("decode_datamatrix"))
			dmtxInfo(status.getBoolean("decode_datamatrix"));

		// update offline cache info
		cacheInfo();
	}
	
	@Override
	public void onResult(ScannerSession session, Result result) {
		this.session = session;
		
		if (result != null) {
			// disable tap-on-screen
			findViewById(R.id.touch).setClickable(false);
			// show result
			displayResult(result.getValue());
		}

	}

	//-------------------------------------
	// SlidingDrawer.OnDrawerListeners
	//-------------------------------------
	@Override
	public void onDrawerClosed() {
		allInfoVisible(true);
		// resume scanning
		session.resume();
		// re-enable online search by tap-on-screen
		findViewById(R.id.touch).setClickable(true);
	}

	@Override
	public void onDrawerOpened() {
		allInfoVisible(false);
	}
	
	//----------------------
	// Scanner.SyncListener
	//----------------------

	@Override
	public void onSyncStart() {
		// void implementation
	}

	@Override
	public void onSyncComplete() {
		cacheInfo();
	}

	@Override
	public void onSyncFailed(MoodstocksError e) {
		e.log();
		cacheInfo();
	}

	@Override
	public void onSyncProgress(int total, int current) {
		cacheInfo(total, current);
	}

}
