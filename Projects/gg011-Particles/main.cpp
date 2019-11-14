#include "stdafx.h"
#include "ThrowOnFail.h"
#include "Game.h"
#include <chrono>

Egg::AppP app;
Microsoft::WRL::ComPtr<IDXGIFactory2> dxgiFactory;
Microsoft::WRL::ComPtr<ID3D11Device> device;
Microsoft::WRL::ComPtr<ID3D11DeviceContext> context;
Microsoft::WRL::ComPtr<IDXGISwapChain1> swapChain;

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam);

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE, PWSTR pCmdLine, int nCmdShow)
{
	// Register the window class.
	const wchar_t CLASS_NAME[] = L"D3D11 Window";

	WNDCLASS wc = {};

	wc.lpfnWndProc = WindowProc;
	wc.hInstance = hInstance;
	wc.lpszClassName = CLASS_NAME;

	RegisterClass(&wc);

	// Create the window.

	HWND hwnd = CreateWindowEx(
		0,                              // Optional window styles.
		CLASS_NAME,                     // Window class
		L"Egg17",					// Window text
		WS_OVERLAPPEDWINDOW,            // Window style
										// Size and position
		CW_USEDEFAULT, CW_USEDEFAULT, Game::windowWidth, Game::windowHeight,
		NULL,       // Parent window    
		NULL,       // Menu
		hInstance,  // Instance handle
		NULL        // Additional application data
		);

	if (hwnd == NULL)
	{
		return 0;
	}

	ShowWindow(hwnd, nCmdShow);

	UINT creationFlags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
#if defined(_DEBUG)
	creationFlags |= D3D11_CREATE_DEVICE_DEBUG;
#endif

	D3D_FEATURE_LEVEL featureLevels[] =
	{
		D3D_FEATURE_LEVEL_11_1,
		D3D_FEATURE_LEVEL_11_0
	};

	using namespace Microsoft::WRL;
	// Create the Direct3D 11 API device object and a corresponding context.
	D3D_FEATURE_LEVEL d3dFeatureLevel;

	Egg::ThrowOnFail("Failed to create D3D device.", __FILE__, __LINE__) ^
		D3D11CreateDevice(
			nullptr,					// Specify nullptr to use the default adapter.
			D3D_DRIVER_TYPE_HARDWARE,	// Create a device using the hardware graphics driver.
			0,							// Should be 0 unless the driver is D3D_DRIVER_TYPE_SOFTWARE.
			creationFlags,				// Set debug and Direct2D compatibility flags.
			featureLevels,				// List of feature levels this app can support.
			ARRAYSIZE(featureLevels),	// Size of the list above.
			D3D11_SDK_VERSION,			// Always set this to D3D11_SDK_VERSION for Windows Store apps.
			device.GetAddressOf(),		// Returns the Direct3D device created.
			&d3dFeatureLevel,			// Returns feature level of device created.
			context.GetAddressOf()		// Returns the device immediate context.
			);

	ComPtr<IDXGIDevice3> dxgiDevice;
	Egg::ThrowOnFail("The device is not a DXGI device.", __FILE__, __LINE__) ^
		device.As(&dxgiDevice);

	ComPtr<IDXGIAdapter> dxgiAdapter;
	Egg::ThrowOnFail("Failed to get adapter from device.", __FILE__, __LINE__) ^
		dxgiDevice->GetAdapter(dxgiAdapter.GetAddressOf());

	Egg::ThrowOnFail("Failed to get factory from adapter.", __FILE__, __LINE__) ^
		dxgiAdapter->GetParent(IID_PPV_ARGS(dxgiFactory.GetAddressOf()));

	RECT r;
	GetWindowRect(hwnd, &r);

	DXGI_SWAP_CHAIN_DESC1 swapChainDesc = { 0 };
	swapChainDesc.Width = r.right - r.left; // Match the size of the window.
	swapChainDesc.Height = r.bottom - r.top;
	swapChainDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM; // This is the most common swap chain format.
	swapChainDesc.Stereo = false;
	swapChainDesc.SampleDesc.Count = 1; // Don't use multi-sampling.
	swapChainDesc.SampleDesc.Quality = 0;
	swapChainDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
	swapChainDesc.BufferCount = 2; // Use double-buffering to minimize latency.
	swapChainDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL; // All Windows Store apps must use this SwapEffect.
	swapChainDesc.Flags = 0;
	swapChainDesc.Scaling = DXGI_SCALING_NONE;
	swapChainDesc.AlphaMode = DXGI_ALPHA_MODE_IGNORE;

	Egg::ThrowOnFail("Failed to create swap chain.", __FILE__, __LINE__) ^
		dxgiFactory->CreateSwapChainForHwnd(
			device.Get(),
			hwnd,
			&swapChainDesc,
			nullptr,
			nullptr,
			&swapChain
			);

	app = Game::create(device);

	app->createResources();

	app->setSwapChain(swapChain);
	app->createSwapChainResources();

	// Set the 3D rendering viewport to target the entire window.
	CD3D11_VIEWPORT screenViewport(
		0.0f,
		0.0f,
		swapChainDesc.Width,
		swapChainDesc.Height
		);

	context->RSSetViewports(1, &screenViewport);

	MSG msg = { 0 };

	auto startTime = std::chrono::system_clock::now();
	auto time = startTime;

	while (WM_QUIT != msg.message)
	{
		if (PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE))
		{
			app->processMessage(hwnd, msg.message, msg.wParam, msg.lParam);
			TranslateMessage(&msg);
			DispatchMessage(&msg);
		}
		else
		{
			auto currentTime = std::chrono::system_clock::now();
			std::chrono::duration<double> timeStep = currentTime - time;
			time = currentTime;
			std::chrono::duration<double> timeSinceStart = currentTime - startTime;
			// idle: update, render
			app->animate(timeStep.count(), timeSinceStart.count());
			app->render(context);

			Egg::ThrowOnFail("Failed to present swap chain.", __FILE__, __LINE__) ^
				swapChain->Present(0, 0);
		}
	}
	app->releaseSwapChainResources();
	app->releaseResources();

	return 0;
}

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	using namespace Microsoft::WRL;
	switch (uMsg)
	{
	case WM_SIZE:
	{
		if (app == nullptr || swapChain == nullptr)
			return 0;
		app->releaseSwapChainResources();
		RECT r;
		GetWindowRect(hwnd, &r);

		HRESULT hr = swapChain->ResizeBuffers(
			2,
			0/*r.right - r.left*/,
			0/*r.bottom - r.top*/,
			DXGI_FORMAT_B8G8R8A8_UNORM,
			0
			);

		CD3D11_VIEWPORT screenViewport(
			0.0f,
			0.0f,
			r.right - r.left,
			r.bottom - r.top
			);

		context->RSSetViewports(1, &screenViewport);
		app->setSwapChain(swapChain);
		app->createSwapChainResources();

		return 0;
	}
	case WM_DESTROY:
		PostQuitMessage(0);
		return 0;
	}
	return DefWindowProc(hwnd, uMsg, wParam, lParam);
}
