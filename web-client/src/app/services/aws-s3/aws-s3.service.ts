import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { environment } from 'src/environments/environment';
import { FileInput } from '../../models/fileInput';

@Injectable({
  providedIn: 'root'
})
export class AwsS3Service {

  readonly BASE_URL = environment.apiUrl;

  constructor(private http: HttpClient) {}

  getPresignedUrlUpload(inputFileName: string) {
    return this.http.get(`${this.BASE_URL}/presigned-url?key=${inputFileName}`)
  }

  uploadFile(presignedUrl: any, inputFileName: string, fileContent: string) {
    const formData = new FormData();
    Object.keys(presignedUrl.fields).forEach(key => {
      formData.append(key, presignedUrl.fields[key]);
    });
    formData.append("key", inputFileName);
    formData.append("file", fileContent);
    return this.http.post(presignedUrl.url, formData)
  }

  processFiles(filesInput: FileInput[]) {
    const body = {
      files: filesInput.map(file => { return {
        input: file.inputFileName,
        output: file.outputFileName
      }})
    };
    return this.http.post(`${this.BASE_URL}/process`, body)
  }

  downloadFile(presignedUrl: string) {
    return this.http.get(presignedUrl)
  }
}
