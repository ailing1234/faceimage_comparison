package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
)

func main() {
	// Ensure uploads directory exists
	if err := os.MkdirAll("uploads", os.ModePerm); err != nil {
		log.Fatalf("Failed to create uploads directory: %v", err)
	}

	http.HandleFunc("/api/verify-face", handleFaceVerification)

	fmt.Println("Server started at :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func handleFaceVerification(w http.ResponseWriter, r *http.Request) {
	// CORS for local Flutter Web
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	// Limit upload size to 10MB
	r.Body = http.MaxBytesReader(w, r.Body, 10<<20)

	err := r.ParseMultipartForm(10 << 20)
	if err != nil {
		log.Println("❌ Error parsing multipart form:", err)
		http.Error(w, "Could not parse multipart form", http.StatusBadRequest)
		return
	}

	// Parse form files
	idFile, idHeader, err := r.FormFile("id_image")
	if err != nil {
		log.Println("❌ id_image missing:", err)
		http.Error(w, "id_image is required", http.StatusBadRequest)
		return
	}
	defer idFile.Close()

	faceFile, faceHeader, err := r.FormFile("face_image")
	if err != nil {
		log.Println("❌ face_image missing:", err)
		http.Error(w, "face_image is required", http.StatusBadRequest)
		return
	}
	defer faceFile.Close()

	// Save files
	idPath := filepath.Join("uploads", idHeader.Filename)
	facePath := filepath.Join("uploads", faceHeader.Filename)

	if err := saveUploadedFile(idFile, idPath); err != nil {
		log.Println("❌ Failed to save ID image:", err)
		http.Error(w, "Failed to save id image", http.StatusInternalServerError)
		return
	}

	if err := saveUploadedFile(faceFile, facePath); err != nil {
		log.Println("❌ Failed to save face image:", err)
		http.Error(w, "Failed to save face image", http.StatusInternalServerError)
		return
	}

	// TODO: Add face comparison logic

	// Send success response
	log.Println("✅ Files uploaded successfully:", idPath, facePath)

	// Prepare the request
	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)

	// Add first image
	img1File, err := os.Open(idPath)
	if err != nil {
		panic(err)
	}
	defer img1File.Close()

	img1Part, _ := writer.CreateFormFile("img1", "id_image.jpg")
	io.Copy(img1Part, img1File)

	// Add second image
	img2File, err := os.Open(facePath)
	if err != nil {
		panic(err)
	}
	defer img2File.Close()

	img2Part, _ := writer.CreateFormFile("img2", "face_image.jpg")
	io.Copy(img2Part, img2File)

	writer.Close()

	// Send POST request to DeepFace API
	resp, err := http.Post("http://localhost:5000/verify", writer.FormDataContentType(), body)
	if err != nil {
		panic(err)
	}
	defer resp.Body.Close()

	// Parse response
	var result map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&result)

	fmt.Println("DeepFace verification result:")
	fmt.Printf("%+v\n", result)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)

	json.NewEncoder(w).Encode(result)
}

func saveUploadedFile(file multipart.File, path string) error {
	out, err := os.Create(path)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, file)
	return err
}
