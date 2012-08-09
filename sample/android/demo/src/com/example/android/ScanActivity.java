package com.example.android;

import com.moodstocks.android.*;

import android.app.Activity;
import android.app.ProgressDialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.view.Gravity;
import android.view.SurfaceView;
import android.view.View;
import android.widget.SlidingDrawer;
import android.widget.Toast;

public class ScanActivity extends Activity implements ScannerSession.Listener, View.OnClickListener, ProgressDialog.OnCancelListener {

	//-----------------------------------
	// Interface implemented by overlays
	//-----------------------------------
	public static interface Listener {
		/* send a new result to Overlay */
		public void onResult(ScannerSession session, Result result);
		/* send any other information in a Bundle */
		public void onStatusUpdate(Bundle status);
	}

	// Enabled scanning types: configure it according to your needs.
	// Here we allow Image recognition, EAN13 and QRCodes decoding.
	// Feel free to add `EAN8` if you want in addition to decode EAN-8.
	private int ScanOptions = Result.Type.IMAGE | Result.Type.EAN13 | Result.Type.QRCODE;

	public static final String TAG = "Main";
	private ScannerSession session;
	private Overlay overlay;
	private View touch;
	private Bundle status;
	private ProgressDialog searching;

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.main);
	}

	@Override
	protected void onResume() {
		super.onResume();
		// initialize the overlay, that will display results and informations
		overlay = (Overlay) findViewById(R.id.overlay);
		overlay.init();
		// initialize the tap-on-screen
		touch = findViewById(R.id.touch);
		touch.setOnClickListener(this);
		// get the camera preview surface
		SurfaceView preview = (SurfaceView) findViewById(R.id.preview);
		
		// Create a scanner session
		try {
			session = new ScannerSession(this, this, preview);
		} catch (MoodstocksError e) {
			e.log();
		}
		// set session options
		session.setOptions(ScanOptions);
		// start scanning!
		session.resume();
		
		// Send information to the overlay
		status = new Bundle();
		status.putBoolean("decode_ean_8", (ScanOptions & Result.Type.EAN8) != 0);
		status.putBoolean("decode_ean_13", (ScanOptions & Result.Type.EAN13) != 0);
		status.putBoolean("decode_qrcode", (ScanOptions & Result.Type.QRCODE) != 0);
		overlay.onStatusUpdate(status);
	}

	@Override
	protected void onPause() {
		super.onPause();
		session.close();
		finish();
	}
	
	@Override
	public void onBackPressed() {
		SlidingDrawer drawer = (SlidingDrawer) findViewById(R.id.drawer);
		if (drawer.isOpened()) {
			drawer.animateClose();
		}
		else {
			super.onBackPressed();
		}
	}

	//-------------------------
	// ScannerSession.Listener
	//-------------------------

	@Override
	public void onScanComplete(Result result) {
		if (result != null) {
			// pause scanning session
			session.pause();
			// result found, send to overlay
			overlay.onResult(session, result);
		}
	}
	
	@Override
	public void onApiSearchStart() {
		// inform user
		searching = ProgressDialog.show(this, "", "Searching...", true, true, this);
	}
	
	@Override
	public void onApiSearchComplete(Result result) {
		searching.dismiss();
		if (result != null) {
			// pause scanning session
			session.pause();
			// result found, send to overlay
			overlay.onResult(session, result);
		}
		else {
			// no result found, inform user
			Toast t = Toast.makeText(this, "No match found", Toast.LENGTH_SHORT);
			t.setGravity(Gravity.CENTER_HORIZONTAL|Gravity.BOTTOM, 0, 200);
			t.show();
		}
	}
	
	
	@Override
	public void onApiSearchFailed(MoodstocksError e) {
		searching.dismiss();
		// A problem occurred, e.g. there is no available network. Inform user:
		Toast t = Toast.makeText(this, e.getMessage(), Toast.LENGTH_SHORT);
		t.setGravity(Gravity.CENTER_HORIZONTAL|Gravity.BOTTOM, 0, 200);
		t.show();
	}
	
	//----------------------
	// View.OnClickListener
	//----------------------
	
	// Intercept tap-on-screen:
	@Override
	public void onClick(View v) {
		if (v == touch) {
			session.snap();
		}
	}
	
	//---------------------------------
	// ProgressDialog.OnCancelListener
	//---------------------------------
	
	// User cancelled snap
	@Override
	public void onCancel(DialogInterface dialog) {
		if (dialog == this.searching) {
			session.cancel();
		}
	}
	
	
}